# Validation for 1.1.0

Validated on an Apple silicon Mac running macOS 27 with Swift 6.4, compiling in
Swift 5 language mode and targeting macOS 13.

## Passed

- Universal binary compilation: arm64 and x86_64 slices.
- 219 power-state and transition assertions, including repeated cable events,
  paused charging, missing/invalid data, battery bounds, and wake initialization.
- All five style choices persist; unknown saved styles fall back to Connector.
- Preferences restore correctly without touching the user's settings in tests.
- All five actual AppKit overlays in both directions: visible, click-through,
  nonactivating, and automatically dismissed at their expected lifetimes.
- Screen Edge uses the full selected display bounds.
- 25 rapid replacements across styles, repeated dismissal, and display-change cleanup.
- Main window inspected in native dark appearance, including Screen Edge and Underline.
- Standalone build from a separate source folder with spaces in its path.
- DMG checksum verification, read-only mounting, Applications shortcut, app metadata,
  and strict verification of the enclosed app's local code signature.

## Manual coverage still needed

- Runtime on Intel hardware and older supported macOS releases.
- Fullscreen apps across multiple Spaces, external monitors, and display hot-plugging.
- VoiceOver navigation and system Reduce Motion on supported OS versions.
- Physical cable events for every style and listening tests at different system volumes.
- Apple Developer ID signing/notarization, which requires the release owner's credentials.

The included GitHub Actions workflow is ready to run after upload; it has not run
against a remote repository during this local build. Local tests do not guarantee
an absence of bugs on every hardware and OS combination.
