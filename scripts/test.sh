#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="${CURRENT_BUILD_DIR:-$PWD/.build}"
mkdir -p "$build_dir"
swiftc -swift-version 5 Sources/PowerState.swift Tests/PowerStateTests.swift -o "$build_dir/PowerStateTests"
"$build_dir/PowerStateTests"
swiftc -swift-version 5 -D TESTING Sources/*.swift Tests/PreferencesTests.swift \
  -o "$build_dir/PreferencesTests" -framework AppKit -framework SwiftUI -framework IOKit
"$build_dir/PreferencesTests"
if [ "${1:-}" = --ui ]; then
  swiftc -swift-version 5 -D TESTING Sources/*.swift Tests/OverlayTests.swift \
    -o "$build_dir/OverlayTests" -framework AppKit -framework SwiftUI -framework IOKit
  "$build_dir/OverlayTests"
elif [ -n "${1:-}" ]; then
  printf 'Usage: %s [--ui]\n' "$0" >&2; exit 2
fi
