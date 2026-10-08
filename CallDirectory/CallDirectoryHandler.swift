import CallKit
import os

/// Feeds the block list to CallKit, one chunk per request.
///
/// Millions of numbers don't fit in a single request (extensions are reported to fail
/// around 2M), so each request adds the next chunk incrementally and records how far
/// it got. The app keeps reloading the extension until the whole plan is in.
final class CallDirectoryHandler: CXCallDirectoryProvider {
    private let log = Logger(subsystem: "cl.urcalab.chao600", category: "CallDirectory")

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self
        let state = SharedState()
        let plan = BlockPlan(config: state.config)
        let request = plan.nextRequest(after: state.loaded, isIncremental: context.isIncremental, chunkSize: state.chunkSize)

        if request.removeAll {
            context.removeAllBlockingEntries()
        }
        if let slice = request.slice {
            var number = slice.first
            while number <= slice.last {
                // Drain autoreleased objects regularly to keep the extension under its memory limit.
                autoreleasepool {
                    let end = min(number + 50_000, slice.last + 1)
                    while number < end {
                        context.addBlockingEntry(withNextSequentialPhoneNumber: number)
                        number += 1
                    }
                }
            }
        }

        // Recorded before completing; the app rolls it back if the reload fails.
        state.loaded = request.progress
        log.info("\(context.isIncremental ? "Incremental" : "Full") load: \(request.progress.count)/\(plan.total) of \(plan.id)")
        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: any Error) {
        log.error("Request failed: \(error.localizedDescription)")
    }
}
