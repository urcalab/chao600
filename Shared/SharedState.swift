import Foundation

/// State the app and the Call Directory extension share through the App Group.
///
/// Stored as small JSON files rather than UserDefaults: the extension is killed right
/// after it completes, and each process must read what the other just wrote.
struct SharedState {
    static let appGroup = "group.cl.urcalab.chao600"
    static let defaultChunkSize: Int64 = 1_000_000
    static let minChunkSize: Int64 = 125_000

    /// Written by the app only.
    private struct Settings: Codable {
        var config = BlockConfig()
        /// Numbers the extension adds per reload. The app halves it when a reload fails.
        var chunkSize = SharedState.defaultChunkSize
    }

    private let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
        ?? .temporaryDirectory

    var config: BlockConfig {
        get { settings.config }
        nonmutating set { settings.config = newValue }
    }

    var chunkSize: Int64 {
        get { settings.chunkSize }
        nonmutating set { settings.chunkSize = newValue }
    }

    var loaded: LoadProgress {
        get { read("loaded.json") ?? LoadProgress() }
        nonmutating set { write(newValue, to: "loaded.json") }
    }

    private var settings: Settings {
        get { read("settings.json") ?? Settings() }
        nonmutating set { write(newValue, to: "settings.json") }
    }

    private func read<Value: Decodable>(_ name: String) -> Value? {
        guard let data = try? Data(contentsOf: directory.appending(path: name)) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func write(_ value: some Encodable, to name: String) {
        try? JSONEncoder().encode(value).write(to: directory.appending(path: name), options: .atomic)
    }
}
