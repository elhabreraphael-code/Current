#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_dir="$PWD"
build_dir="${CURRENT_BUILD_DIR:-$project_dir/.build}"
dist_dir="${CURRENT_DIST_DIR:-$project_dir/dist}"
if [ "${1:-}" != --skip-build ]; then bash build.sh --universal; fi
app_dir="$dist_dir/Current.app"
[ -d "$app_dir" ] || { printf 'Build Current.app first.\n' >&2; exit 1; }
mkdir -p "$build_dir" "$dist_dir"
# Disk image contents must be staged outside file-provider/cloud folders.
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/current-dmg.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
ditto --norsrc --noextattr "$app_dir" "$staging_dir/Current.app"
xattr -cr "$staging_dir/Current.app"
codesign --verify --strict "$staging_dir/Current.app"
ln -s /Applications "$staging_dir/Applications"
cp docs/Install.txt "$staging_dir/Read Me.txt"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_dir/Contents/Info.plist")
dmg_path="$dist_dir/Current-$version.dmg"
hdiutil create -volname Current -srcfolder "$staging_dir" -format UDZO -ov "$dmg_path"
if [ -n "${SIGNING_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$dmg_path"
fi
hdiutil verify "$dmg_path"
printf 'Created %s\n' "$dmg_path"
