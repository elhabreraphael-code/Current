# Current

**A small moment for your Mac.**

Current is a native macOS menu bar app that quietly acknowledges plugging in and
unplugging power. Five understated animations, a gentler reverse on disconnect,
and optional soft sound. Built with SwiftUI, AppKit, and IOKit. MIT licensed.

## Five ways to say hello

| Style | Plug in | Unplug |
| --- | --- | --- |
| Connector | A small connection card joins its cable | The cable separates softly |
| Screen Edge | A thin mint glow traces the whole display | The trace quietly retracts |
| Halo | A circle of energy forms around a small bolt | The circle unwinds |
| Ripple | Three fine rings expand near the bottom of the screen | The rings return inward |
| Underline | A fine line grows above the Dock | The line folds back into its center |

Choose a style in the app or menu bar; your choice is saved. Use **Plug in** or
**Unplug**, then **Preview animation**, to try either direction. Previews work even
when automatic power animations are disabled.

Ambient effects use the display containing the pointer. Screen Edge follows that
display's entire physical bounds; macOS reserves any camera cutout. Other styles
stay within its usable area. Effects never take keyboard focus or intercept clicks.
A new event replaces the old effect; display configuration changes dismiss it.

## Use

1. Open the DMG and drag **Current.app** into **Applications**.
2. Open Current and choose an animation style.
3. Close the window to keep it running in the menu bar.

The live battery reading is separate from the selectable animation illustration.
Connected power can legitimately show “Not charging” when macOS pauses charging.
Sound starts off; when enabled, unplug plays a descending tone at less than half
the connect volume. Battery percentage in the menu bar is optional.

Current follows light/dark appearance and Reduce Motion. With Reduce Motion,
ambient effects gently fade instead of tracing or scaling. Current requires no
account, network connection, Accessibility access, analytics, or background polling.
Preferences stay on your Mac. Automatic launch at login is not included.

**Compatibility:** macOS 13+ deployment target; universal Apple silicon and Intel
build. Tested at runtime on Apple silicon. The supplied local DMG is ad-hoc signed,
not Apple notarized; first-launch approval may be required. See
[release instructions](docs/RELEASING.md) for Developer ID signing and notarization.

## Build from source

Install Apple's Command Line Tools and Python 3. No Xcode project or third-party
packages are required. From this folder:

```sh
bash scripts/test.sh
bash build.sh
open dist/Current.app
```

Build both architectures and create the DMG:

```sh
bash build.sh --universal
bash scripts/create-dmg.sh --skip-build
```

Build output stays in `.build/` and `dist/`, both ignored by Git. Optional
`CURRENT_BUILD_DIR` and `CURRENT_DIST_DIR` environment variables override those
locations. You can open the source folder in your preferred editor; the shell
build is the canonical build.

## Test

```sh
bash scripts/test.sh       # Power interpretation, transitions, preferences
bash scripts/test.sh --ui  # Also show/test all five native overlays in both directions
```

Tests cover 219 power-state/transition assertions, style persistence and fallback,
focus preservation, click-through windows, full-screen edge geometry, timed cleanup,
rapid cross-style replacement, and display changes. UI tests require a logged-in
macOS desktop. See [QA notes](docs/QA.md) for validation and remaining hardware checks.

## Project layout

```text
Sources/       Native app, power state, style metadata, animation rendering
Resources/     App metadata, original icon and sound generators
Tests/         Power, preference, and AppKit lifecycle checks
scripts/       Test and DMG packaging entry points
.github/       Build/test workflow for GitHub Actions
```

[Contributing](CONTRIBUTING.md) · [Releasing and GitHub upload](docs/RELEASING.md) ·
[Changelog](CHANGELOG.md) · [MIT license](LICENSE)
