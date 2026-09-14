# Contributing

Keep Current small, native, and quiet. Each animation should communicate a power
change, reverse gently on unplug, and disappear without taking focus or mouse input.

1. Use macOS 13+ with Apple's Command Line Tools and Python 3.
2. Run `bash scripts/test.sh`, then `bash build.sh`.
3. Run `bash scripts/test.sh --ui` in a logged-in macOS desktop session. These tests briefly show all ten effects.
4. Manually preview both directions of every changed style, including Reduce Motion,
   light/dark appearance, fullscreen Spaces, a notched screen, and external monitors.
5. Include the behavior change and validation in your pull request.

No third-party dependencies are required. Use `Sources/AnimationStyle.swift` for
style metadata, `Sources/Animations.swift` for rendering and overlay lifecycle,
and `Sources/PowerState.swift` for independently testable power interpretation.

Do not include signing certificates, credentials, local preferences, or build
products in commits. Developer ID signing and notarization are maintainer tasks.
