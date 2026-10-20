import Foundation

/// Which number families get blocked.
struct BlockConfig: Codable, Equatable, Sendable {
    static let maxAllowed = 100

    var block600 = true
    var block809 = true
    /// Numbers the user always wants to ring, in CallKit's format (see `AllowedNumber`).
    /// Kept sorted and unique.
    var allowed: [Int64] = []
}

extension BlockConfig {
    // In an extension so the memberwise init survives. Settings saved by older versions
    // have no "allowed" (and an obsolete "includeNationalFormat", which is ignored).
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        block600 = try container.decodeIfPresent(Bool.self, forKey: .block600) ?? true
        block809 = try container.decodeIfPresent(Bool.self, forKey: .block809) ?? true
        allowed = Array(Set(try container.decodeIfPresent([Int64].self, forKey: .allowed) ?? [])).sorted()
    }
}

/// A single 600 or 809 number the user typed, as CallKit knows it: country code + digits, no "+".
enum AllowedNumber {
    /// Accepts "600 123 4567", "+56 600 123 4567", "56809123456"… and nothing else.
    static func parse(_ text: String) -> Int64? {
        var digits = text.filter { $0.isASCII && $0.isNumber }
        if digits.hasPrefix("00") { digits.removeFirst(2) }
        if digits.hasPrefix("56") { digits.removeFirst(2) }
        let valid = (digits.hasPrefix("600") && digits.count == 10) || (digits.hasPrefix("809") && digits.count == 9)
        return valid ? Int64("56" + digits) : nil
    }

    /// "600 123 4567" / "809 123 456".
    static func format(_ number: Int64) -> String {
        let digits = String(number).dropFirst(2)
        let groups = [digits.prefix(3), digits.dropFirst(3).prefix(3), digits.dropFirst(6)]
        return groups.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// A run of consecutive phone numbers in CallKit's format: country code + digits, no "+".
struct NumberRange: Equatable, Sendable {
    let first: Int64
    let count: Int64

    var last: Int64 { first + count - 1 }

    /// The pieces of this range that remain after taking `numbers` out, ascending.
    func excluding(_ numbers: [Int64]) -> [NumberRange] {
        var pieces: [NumberRange] = []
        var next = first
        for number in numbers.sorted() where number >= first && number <= last {
            if number > next { pieces.append(NumberRange(first: next, count: number - next)) }
            next = number + 1
        }
        if next <= last { pieces.append(NumberRange(first: next, count: last - next + 1)) }
        return pieces
    }
}

/// What CallKit's database holds: the plan it was built from and how many of its numbers are in.
struct LoadProgress: Codable, Equatable, Sendable {
    var planID = ""
    var count: Int64 = 0
    /// The allowed numbers already kept out of (or taken out of) CallKit's list.
    var allowed: [Int64] = []
}

extension LoadProgress {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planID = try container.decodeIfPresent(String.self, forKey: .planID) ?? ""
        count = try container.decodeIfPresent(Int64.self, forKey: .count) ?? 0
        allowed = try container.decodeIfPresent([Int64].self, forKey: .allowed) ?? []
    }
}

struct LoadRequest: Equatable, Sendable {
    var removeAll: Bool
    /// Allowed numbers that were blocked and must now ring. Ascending.
    var removals: [Int64]
    /// Numbers to block, ascending: allowed numbers that are no longer exceptions, then the next chunk.
    var additions: [NumberRange]
    /// Where the load stands once this request is committed.
    var progress: LoadProgress
}

/// The ordered list of every number to block for a config.
///
/// CallKit has no wildcards, so each prefix is listed in full:
/// 600 numbers have 10 digits (600 XXX XXXX → 10M), 809 numbers have 9 (809 XXX XXX → 1M).
struct BlockPlan: Equatable, Sendable {
    /// Bump when the ranges change so installed apps rebuild their list from scratch.
    static let version = 2

    static let international809 = NumberRange(first: 56_809_000_000, count: 1_000_000)
    static let international600 = NumberRange(first: 566_000_000_000, count: 10_000_000)

    let id: String
    let ranges: [NumberRange]
    /// The config's allowed numbers that fall inside the ranges. Not part of `id`: changing
    /// them edits CallKit's list in place instead of reloading millions of numbers.
    let allowed: [Int64]

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
        self.ranges = ranges
        self.id = "v\(Self.version):" + parts.joined(separator: "+")
        self.allowed = Array(Set(config.allowed)).sorted().filter { number in
            ranges.contains { $0.first <= number && number <= $0.last }
        }
    }

    var total: Int64 { ranges.reduce(0) { $0 + $1.count } }

    /// Whether CallKit already holds everything this plan asks for.
    func isLoaded(_ progress: LoadProgress) -> Bool {
        progress.planID == id && progress.count >= total && progress.allowed == allowed
    }

    /// Where `number` sits in the plan's order, or nil if the plan doesn't cover it.
    func position(of number: Int64) -> Int64? {
        var before: Int64 = 0
        for range in ranges {
            if range.first <= number, number <= range.last { return before + number - range.first }
            before += range.count
        }
        return nil
    }

    /// What one Call Directory request should do, given what CallKit already holds.
    func nextRequest(after progress: LoadProgress, isIncremental: Bool, chunkSize: Int64) -> LoadRequest {
        // A non-incremental request starts from an empty list; a plan change needs a clean one.
        let keepsProgress = isIncremental && progress.planID == id
        let start = keepsProgress ? progress.count : 0
        let applied = keepsProgress ? progress.allowed : []
        let slice = slice(after: start, maxCount: chunkSize)

        // Only numbers already loaded need an edit; the rest are skipped or added with their chunk.
        func isLoaded(_ number: Int64) -> Bool { (position(of: number) ?? .max) < start }
        let removals = allowed.filter { !applied.contains($0) && isLoaded($0) }
        let restores = applied.filter { !allowed.contains($0) && isLoaded($0) }.sorted()

        var additions = restores.map { NumberRange(first: $0, count: 1) }
        if let slice { additions += slice.excluding(allowed) }

        return LoadRequest(
            removeAll: isIncremental && !keepsProgress,
            removals: removals,
            additions: additions,
            progress: LoadProgress(planID: id, count: start + (slice?.count ?? 0), allowed: allowed)
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
