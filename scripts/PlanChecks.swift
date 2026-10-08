// Sanity checks for BlockPlan, runnable without Xcode: scripts/check-plan.sh

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
check(BlockPlan.national600.last == 6_009_999_999 && BlockPlan.national809.last == 809_999_999, "national")
check(!(i600.first...i600.last).contains(56_601_000_0000), "601 is not blocked")
check(!(i809.first...i809.last).contains(56_912_345_678), "mobiles are not blocked")

// Default plan: 809 then 600, 11M numbers.
let plan = BlockPlan(config: BlockConfig())
check(plan.id == "v1:809+600", "id is \(plan.id)")
check(plan.total == 11_000_000, "total is \(plan.total)")

// Walking the plan in chunks yields every number once, each slice inside one range.
for chunk: Int64 in [1_000_000, 300_000, 125_000] {
    let full = BlockPlan(config: BlockConfig(includeNationalFormat: true))
    var offset: Int64 = 0
    var slices = 0
    while let slice = full.slice(after: offset, maxCount: chunk) {
        check(slice.count > 0 && slice.count <= chunk, "slice size")
        check(full.ranges.contains { $0.first <= slice.first && slice.last <= $0.last }, "slice inside a range")
        offset += slice.count
        slices += 1
    }
    check(offset == full.total && full.total == 22_000_000, "covers \(offset)")
    print("chunk \(chunk): \(slices) reloads for \(full.total) numbers")
}

check(BlockPlan(config: BlockConfig(block600: false, block809: false)).total == 0, "empty plan")
check(BlockPlan(config: BlockConfig()).id != BlockPlan(config: BlockConfig(block809: false)).id, "ids differ")

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

var totalReloads = 0
for seed: UInt64 in 1...200 {
    var random = SeededRandom(state: seed)
    var callKit: [NumberRange] = []
    var progress = LoadProgress()
    var config = BlockConfig()
    var chunk: Int64 = 1_000_000
    var everLoaded = false

    func extensionRun(incremental: Bool) -> LoadRequest {
        let request = BlockPlan(config: config).nextRequest(after: progress, isIncremental: incremental, chunkSize: chunk)
        progress = request.progress
        return request
    }
    func commit(_ request: LoadRequest, incremental: Bool) {
        if !incremental || request.removeAll { callKit = [] }
        if let slice = request.slice { callKit.append(slice) }
        everLoaded = true
    }

    var reloads = 0
    while true {
        let plan = BlockPlan(config: config)
        if progress.planID == plan.id, progress.count >= plan.total { break }
        reloads += 1
        check(reloads < 10_000, "seed \(seed): never finished")

        // Disrupt the first reloads, then let the load settle.
        switch reloads < 40 ? Int.random(in: 0..<100, using: &random) : 100 {
        case 0..<4: config.block809.toggle()
        case 4..<6: config.block600.toggle()
        case 6..<8: config.includeNationalFormat.toggle()
        case 8..<11: commit(extensionRun(incremental: false), incremental: false)  // iOS rebuilds on its own
        default: break
        }

        // The app's reload: the extension writes progress, then CallKit commits or fails.
        let incremental = everLoaded && (reloads >= 40 || Int.random(in: 0..<100, using: &random) >= 5)
        let before = progress
        let request = extensionRun(incremental: incremental)
        if Int.random(in: 0..<100, using: &random) < 20 {
            progress = before
            chunk = max(chunk / 2, 125_000)
        } else {
            commit(request, incremental: incremental)
        }
    }

    totalReloads += reloads
    let plan = BlockPlan(config: config)
    check(callKit.reduce(0) { $0 + $1.count } == plan.total, "seed \(seed): no duplicates")
    check(merged(callKit) == merged(plan.ranges), "seed \(seed): CallKit holds exactly the plan")
}
print("Protocol simulation: 200 runs, \(totalReloads) reloads, CallKit always ended with exactly the plan")
print("All plan checks passed")
