// Sanity checks for BlockPlan, runnable without Xcode: ios/scripts/check-plan.sh

func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition {
        print("FAIL (line \(line)): \(message)")
        exit(1)
    }
}

// Ranges cover exactly the numbers in the screenshot and nothing else.
let i600 = BlockPlan.international600
let i809 = BlockPlan.international809
check(i600.first == 56_600_000_0000 && i600.last == 56_600_999_9999, "+56 600 XXX XXXX")
check(i809.first == 56_809_000_000 && i809.last == 56_809_999_999, "+56 809 XXX XXX")
check((i600.first...i600.last).contains(56_600_604_0018), "+56 600 604 0018 is blocked")
check((i809.first...i809.last).contains(56_809_025_226), "+56 8 0902 5226 is blocked")
check(!(i600.first...i600.last).contains(56_601_000_0000), "601 is not blocked")
check(!(i809.first...i809.last).contains(56_912_345_678), "mobiles are not blocked")

// Default plan: 809 then 600, 11M numbers.
let plan = BlockPlan(config: BlockConfig())
check(plan.id == "v2:809+600", "id is \(plan.id)")
check(plan.total == 11_000_000, "total is \(plan.total)")
check(plan.isLoaded(LoadProgress(planID: plan.id, count: plan.total)), "loaded when every number is in")
check(!plan.isLoaded(LoadProgress(planID: plan.id, count: plan.total, allowed: [56_809_123_456])), "not loaded while an allowed number differs")

// Walking the plan in chunks yields every number once, each slice inside one range.
for chunk: Int64 in [1_000_000, 300_000, 125_000] {
    var offset: Int64 = 0
    var slices = 0
    while let slice = plan.slice(after: offset, maxCount: chunk) {
        check(slice.count > 0 && slice.count <= chunk, "slice size")
        check(plan.ranges.contains { $0.first <= slice.first && slice.last <= $0.last }, "slice inside a range")
        offset += slice.count
        slices += 1
    }
    check(offset == plan.total, "covers \(offset)")
    print("chunk \(chunk): \(slices) reloads for \(plan.total) numbers")
}

check(BlockPlan(config: BlockConfig(block600: false, block809: false)).total == 0, "empty plan")
check(BlockPlan(config: BlockConfig()).id != BlockPlan(config: BlockConfig(block809: false)).id, "ids differ")

// Allowed numbers: what the user types, what CallKit stores, and what the plan keeps out.
check(AllowedNumber.parse("600 123 4567") == 56_600_123_4567, "national 600")
check(AllowedNumber.parse("+56 809 123 456") == 56_809_123_456, "+56 809")
check(AllowedNumber.parse("0056 600 123 4567") == 56_600_123_4567, "0056 prefix")
check(AllowedNumber.parse("600 123 456") == nil && AllowedNumber.parse("9 1234 5678") == nil, "rejects other numbers")
check(AllowedNumber.format(56_600_123_4567) == "600 123 4567" && AllowedNumber.format(56_809_123_456) == "809 123 456", "format")
check(NumberRange(first: 10, count: 10).excluding([25, 15, 9, 10, 19]) == [NumberRange(first: 11, count: 4), NumberRange(first: 16, count: 3)], "excluding")

let partial = BlockPlan(config: BlockConfig(block600: false, allowed: [56_600_123_4567, 56_809_123_456, 56_912_345_678]))
check(partial.allowed == [56_809_123_456], "only allowed numbers the plan covers count")
check(partial.id == BlockPlan(config: BlockConfig(block600: false)).id, "allowed numbers don't change the plan id")

// Settings and progress written by older versions still load.
let decoder = JSONDecoder()
let oldConfig = try! decoder.decode(BlockConfig.self, from: Data(#"{"block600":true,"block809":false,"includeNationalFormat":true}"#.utf8))
check(oldConfig == BlockConfig(block809: false), "obsolete includeNationalFormat is ignored")
let repeated = try! decoder.decode(BlockConfig.self, from: Data(#"{"allowed":[56809000002,56809000001,56809000002]}"#.utf8))
check(repeated == BlockConfig(allowed: [56_809_000_001, 56_809_000_002]), "allowed numbers decode sorted and unique")
let oldProgress = try! decoder.decode(LoadProgress.self, from: Data(#"{"planID":"v1:809+600","count":3000000}"#.utf8))
check(oldProgress == LoadProgress(planID: "v1:809+600", count: 3_000_000), "progress without allowed numbers")

// Simulate the app ↔ extension ↔ CallKit protocol with failures, iOS-initiated full
// reloads and config changes; CallKit must end up holding exactly the plan, once.
struct SeededRandom: RandomNumberGenerator {  // SplitMix64
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func merged(_ ranges: [NumberRange]) -> [NumberRange] {
    var result: [NumberRange] = []
    for range in ranges.sorted(by: { $0.first < $1.first }) {
        if let previous = result.last, previous.last + 1 == range.first {
            result[result.count - 1] = NumberRange(first: previous.first, count: previous.count + range.count)
        } else {
            result.append(range)
        }
    }
    return result
}

/// CallKit's list as sorted, disjoint ranges. On a device, adding a number the list already
/// holds or removing one it doesn't fails the whole request, so both stop the checks here.
struct CallKitList {
    var ranges: [NumberRange] = []

    mutating func remove(_ number: Int64, _ context: String) {
        guard let i = ranges.firstIndex(where: { $0.first <= number && number <= $0.last }) else {
            check(false, "\(context): removes \(number), which isn't in the list")
            return
        }
        ranges.replaceSubrange(i...i, with: ranges[i].excluding([number]))
    }

    mutating func add(_ range: NumberRange, _ context: String) {
        check(!ranges.contains { $0.first <= range.last && range.first <= $0.last }, "\(context): adds numbers already in the list")
        ranges = merged(ranges + [range])
    }
}

var totalReloads = 0
for seed: UInt64 in 1...200 {
    var random = SeededRandom(state: seed)
    var callKit = CallKitList()
    var progress = LoadProgress()
    var config = BlockConfig()
    var chunk: Int64 = 1_000_000
    var everLoaded = false
    let context = "seed \(seed)"

    func extensionRun(incremental: Bool) -> LoadRequest {
        let request = BlockPlan(config: config).nextRequest(after: progress, isIncremental: incremental, chunkSize: chunk)
        progress = request.progress
        return request
    }
    func commit(_ request: LoadRequest, incremental: Bool) {
        check(incremental || request.removals.isEmpty, "\(context): a full load has nothing to remove")
        if !incremental || request.removeAll { callKit = CallKitList() }
        for number in request.removals { callKit.remove(number, context) }
        var previous = Int64.min
        for range in request.additions {
            check(range.count > 0 && range.first > previous, "\(context): additions are ascending")
            previous = range.last
            callKit.add(range, context)
        }
        everLoaded = true
    }
    // Usually a number already in the list, sometimes one further on, sometimes a mobile the plan ignores.
    func someNumber() -> Int64 {
        switch Int.random(in: 0..<3, using: &random) {
        case 0: i809.first + Int64.random(in: 0..<i809.count, using: &random)
        case 1: i600.first + Int64.random(in: 0..<3_000_000, using: &random)
        default: 56_912_345_678
        }
    }
    func allowSomeNumber() {
        let number = someNumber()
        if !config.allowed.contains(number), config.allowed.count < BlockConfig.maxAllowed {
            config.allowed = (config.allowed + [number]).sorted()
        }
    }
    func stopAllowingSomeNumber() {
        if !config.allowed.isEmpty { config.allowed.remove(at: Int.random(in: 0..<config.allowed.count, using: &random)) }
    }

    // The app's sync loop. The first `disruptions` reloads may see config changes and iOS rebuilds.
    // With `inPlace`, the plan is already loaded and only allowed numbers change.
    func sync(disruptions: Int, inPlace: Bool) {
        var round = 0
        while !BlockPlan(config: config).isLoaded(progress) {
            round += 1
            totalReloads += 1
            check(round < 10_000, "\(context): never finished")

            switch round <= disruptions ? Int.random(in: 0..<100, using: &random) : 100 {
            case 0..<4: config.block809.toggle()
            case 4..<6: config.block600.toggle()
            case 6..<12: allowSomeNumber()
            case 12..<15: stopAllowingSomeNumber()
            case 15..<18: commit(extensionRun(incremental: false), incremental: false)  // iOS rebuilds on its own
            default: break
            }

            // The app's reload: the extension writes progress, then CallKit commits or fails.
            let incremental = everLoaded && (round > disruptions || Int.random(in: 0..<100, using: &random) >= 5)
            let before = progress
            let request = extensionRun(incremental: incremental)
            check(!inPlace || (!request.removeAll && request.progress.count == before.count), "\(context): edits the list in place")
            if Int.random(in: 0..<100, using: &random) < 20 {
                progress = before
                chunk = max(chunk / 2, 125_000)
            } else {
                commit(request, incremental: incremental)
            }
        }
        let plan = BlockPlan(config: config)
        let expected = plan.ranges.flatMap { $0.excluding(plan.allowed) }
        check(merged(callKit.ranges) == merged(expected), "\(context): CallKit holds exactly the plan minus the allowed numbers")
    }

    sync(disruptions: 40, inPlace: false)
    for _ in 0..<3 {
        allowSomeNumber()
        if Int.random(in: 0..<2, using: &random) == 0 { stopAllowingSomeNumber() }
        sync(disruptions: 0, inPlace: true)
    }
}
print("Protocol simulation: 200 runs, \(totalReloads) reloads, CallKit always ended with exactly the plan")
print("All plan checks passed")
