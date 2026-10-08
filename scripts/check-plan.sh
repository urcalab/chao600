#!/bin/sh
# Compiles the shared block-list logic with a few checks and runs it on the Mac.
set -e
cd "$(dirname "$0")/.."
out="$(mktemp -d)"
cat Shared/BlockPlan.swift scripts/PlanChecks.swift > "$out/main.swift"
swiftc -O "$out/main.swift" -o "$out/checks"
"$out/checks"
