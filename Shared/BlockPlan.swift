import Foundation

/// Which number families get blocked.
struct BlockConfig: Codable, Equatable, Sendable {
    var block600 = true
    var block809 = true
    /// Also list the numbers without the 56 country code, for carriers that
    /// deliver the caller ID in national format. Doubles the load.
    var includeNationalFormat = false
}

/// A run of consecutive phone numbers in CallKit's format: country code + digits, no "+".
struct NumberRange: Equatable, Sendable {
    let first: Int64
    let count: Int64

    var last: Int64 { first + count - 1 }
}

/// What CallKit's database holds: the plan it was built from and how many of its numbers are in.
struct LoadProgress: Codable, Equatable, Sendable {
    var planID = ""
    var count: Int64 = 0
}

struct LoadRequest: Equatable, Sendable {
    var removeAll: Bool
    var slice: NumberRange?
    /// Where the load stands once this request is committed.
    var progress: LoadProgress
}

/// The ordered list of every number to block for a config.
///
/// CallKit has no wildcards, so each prefix is listed in full:
/// 600 numbers have 10 digits (600 XXX XXXX → 10M), 809 numbers have 9 (809 XXX XXX → 1M).
struct BlockPlan: Equatable, Sendable {
    /// Bump when the ranges change so installed apps rebuild their list from scratch.
    static let version = 1

    static let international809 = NumberRange(first: 56_809_000_000, count: 1_000_000)
    static let international600 = NumberRange(first: 566_000_000_000, count: 10_000_000)
    static let national809 = NumberRange(first: 809_000_000, count: 1_000_000)
    static let national600 = NumberRange(first: 6_000_000_000, count: 10_000_000)

    let id: String
    let ranges: [NumberRange]

    init(config: BlockConfig) {
        var ranges: [NumberRange] = []
        var parts: [String] = []
        // 809 goes first: it's small, so telemarketing is blocked after the first reload.
        if config.block809 {
            ranges.append(Self.international809)
            parts.append("809")
        }
        if config.block600 {
            ranges.append(Self.international600)
            parts.append("600")
        }
        if config.includeNationalFormat {
            if config.block809 { ranges.append(Self.national809) }
            if config.block600 { ranges.append(Self.national600) }
            parts.append("national")
        }
        self.ranges = ranges
        self.id = "v\(Self.version):" + parts.joined(separator: "+")
    }

    var total: Int64 { ranges.reduce(0) { $0 + $1.count } }

    /// What one Call Directory request should do, given what CallKit already holds.
    func nextRequest(after progress: LoadProgress, isIncremental: Bool, chunkSize: Int64) -> LoadRequest {
        // A non-incremental request starts from an empty list; a plan change needs a clean one.
        let keepsProgress = isIncremental && progress.planID == id
        let start = keepsProgress ? progress.count : 0
        let slice = slice(after: start, maxCount: chunkSize)
        return LoadRequest(
            removeAll: isIncremental && !keepsProgress,
            slice: slice,
            progress: LoadProgress(planID: id, count: start + (slice?.count ?? 0))
        )
    }

    /// The next numbers to add once the first `offset` are loaded, at most `maxCount`.
    /// Never spans two ranges, so it is always ascending as CallKit requires.
    func slice(after offset: Int64, maxCount: Int64) -> NumberRange? {
        var start = offset
        for range in ranges {
            if start < range.count {
                return NumberRange(first: range.first + start, count: min(range.count - start, maxCount))
            }
            start -= range.count
        }
        return nil
    }
}
