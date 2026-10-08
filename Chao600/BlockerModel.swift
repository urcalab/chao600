import BackgroundTasks
import CallKit
import Observation
import UIKit

/// Drives the Call Directory extension until CallKit holds every number in the plan.
@MainActor @Observable
final class BlockerModel {
    enum Status: Equatable {
        case checking
        /// The extension is off in Settings → Apps → Phone → Call Blocking & Identification.
        case needsSetup
        case loading(done: Int64, total: Int64)
        case active(total: Int64)
        case failed(String)
    }

    static let refreshTaskID = "cl.urcalab.chao600.refresh"

    private(set) var status = Status.checking

    var config: BlockConfig {
        didSet {
            guard config != oldValue else { return }
            shared.config = config
            Task { await sync() }
        }
    }

    private let shared = SharedState()
    private let manager = CXCallDirectoryManager.sharedInstance
    private let extensionID = (Bundle.main.bundleIdentifier ?? "") + ".CallDirectory"
    private var isSyncing = false

    init() {
        config = shared.config
    }

    func refresh() async {
        #if DEBUG
        if let status = Self.screenshotStatus {
            self.status = status
            return
        }
        #endif
        do {
            switch try await manager.enabledStatusForExtension(withIdentifier: extensionID) {
            case .enabled:
                await sync()
            default:
                status = .needsSetup
            }
        } catch {
            status = .failed(Self.message(for: error))
        }
    }

    func openSettings() async {
        try? await manager.openSettings()
    }

    /// Reloads the extension, one chunk per reload, until the current plan is fully loaded.
    /// Re-reads the config every round, so toggling a prefix mid-load just restarts the plan.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Cargar números")
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            isSyncing = false
            UIApplication.shared.isIdleTimerDisabled = false
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }

        var stalls = 0
        while !Task.isCancelled {
            let plan = BlockPlan(config: shared.config)
            let before = shared.loaded
            let done = before.planID == plan.id ? before.count : 0
            if before.planID == plan.id, done >= plan.total {
                status = .active(total: plan.total)
                return
            }
            status = .loading(done: done, total: plan.total)

            do {
                try await manager.reloadExtension(withIdentifier: extensionID)
                stalls = shared.loaded == before ? stalls + 1 : 0
                if stalls >= 3 {
                    status = .failed("La extensión no está avanzando. Desactívala y vuelve a activarla en Ajustes.")
                    return
                }
            } catch {
                // The extension records its progress before CallKit commits it; undo that.
                shared.loaded = before
                switch (error as? CXErrorCodeCallDirectoryManagerError)?.code {
                case .currentlyLoading:
                    try? await Task.sleep(for: .seconds(1))
                case .extensionDisabled:
                    status = .needsSetup
                    return
                case .loadingInterrupted, .maximumEntriesExceeded, .unknown:
                    // Most likely the chunk was too big for the extension's memory budget.
                    guard shared.chunkSize > SharedState.minChunkSize else {
                        status = .failed(Self.message(for: error))
                        return
                    }
                    shared.chunkSize /= 2
                default:
                    status = .failed(Self.message(for: error))
                    return
                }
            }
        }
    }

    #if DEBUG
    /// App Store screenshots come from the simulator, where CallKit doesn't run:
    /// launch with `-screenshot protected|loading|setup` to show that state.
    private static let screenshotStatus: Status? = switch UserDefaults.standard.string(forKey: "screenshot") {
    case "protected": .active(total: 11_000_000)
    case "loading": .loading(done: 4_000_000, total: 11_000_000)
    case "setup": .needsSetup
    default: nil
    }
    #endif

    private static func message(for error: any Error) -> String {
        switch (error as? CXErrorCodeCallDirectoryManagerError)?.code {
        case .noExtensionFound:
            "iOS no encuentra la extensión de bloqueo. Reinstala la app."
        case .maximumEntriesExceeded:
            "iOS no aceptó más números en la lista de bloqueo."
        case .loadingInterrupted:
            "La carga se interrumpió. Vuelve a intentarlo."
        default:
            "iOS no respondió (código \((error as NSError).code)). Vuelve a intentarlo."
        }
    }

    /// iOS may rebuild the list from scratch on its own (e.g. after re-enabling the
    /// extension), leaving only the first chunk; a background refresh tops it up.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        if case .active = status {
            request.earliestBeginDate = .now.addingTimeInterval(12 * 60 * 60)
        }
        try? BGTaskScheduler.shared.submit(request)
    }
}
