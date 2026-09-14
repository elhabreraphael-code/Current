#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
project_dir="$PWD"
build_dir="${CURRENT_BUILD_DIR:-$project_dir/.build}"
dist_dir="${CURRENT_DIST_DIR:-$project_dir/dist}"
# Sign on a local temporary volume so cloud sync cannot inject Finder metadata.
bundle_stage="$(mktemp -d "${TMPDIR:-/tmp}/current-bundle.XXXXXX")"
trap 'rm -rf "$bundle_stage"' EXIT
app_dir="$bundle_stage/Current.app"
mkdir -p "$build_dir/AppIcon.iconset" "$dist_dir" "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
case "${1:-}" in
  --universal) architectures="arm64 x86_64" ;;
  '') architectures="$(uname -m)" ;;
  *) printf 'Usage: %s [--universal]\n' "$0" >&2; exit 2 ;;
esac
for architecture in $architectures; do
  swiftc -swift-version 5 -O -target "$architecture-apple-macosx13.0" Sources/*.swift \
    -o "$build_dir/Current-$architecture" -framework AppKit -framework SwiftUI -framework IOKit
done
if [ "${1:-}" = --universal ]; then
  lipo -create "$build_dir/Current-arm64" "$build_dir/Current-x86_64" -output "$app_dir/Contents/MacOS/Current"
else
  cp "$build_dir/Current-$(uname -m)" "$app_dir/Contents/MacOS/Current"
fi
swift Resources/MakeIcon.swift "$build_dir/AppIcon.iconset"
iconutil -c icns "$build_dir/AppIcon.iconset" -o "$app_dir/Contents/Resources/AppIcon.icns"
python3 Resources/MakeSounds.py "$app_dir/Contents/Resources"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
xattr -cr "$app_dir"
xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
# Cloud folders can reattach Finder metadata while the bundle is assembled.
# Retry only after removing that metadata from our generated bundle.
for attempt in 1 2 3; do
  xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
  if [ -n "${SIGNING_IDENTITY:-}" ]; then
    if codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app_dir"; then break; fi
  else
    if codesign --force --sign - "$app_dir"; then break; fi
  fi
  if [ "$attempt" = 3 ]; then exit 1; fi
done
xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
codesign --verify --strict "$app_dir"
ditto --norsrc --noextattr "$app_dir" "$dist_dir/Current.app"
printf 'Built %s\n' "$dist_dir/Current.app"
