import AppKit

@main
struct OverlayTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let overlay = OverlayController()
        Task { @MainActor in
            let originalKeyWindow = app.keyWindow
            for style in AnimationStyle.allCases {
                for connected in [true, false] {
                    overlay.show(pluggedIn: connected, percent: connected ? 65 : nil, playSound: false, style: style)
                    precondition(overlay.isVisible, "\(style) must be visible")
                    precondition(overlay.ignoresMouseEvents, "Every style must be click-through")
                    precondition(app.keyWindow === originalKeyWindow, "Effects must not steal focus")
                    if style == .screenEdge {
                        precondition(NSScreen.screens.contains { $0.frame == overlay.activeFrame }, "Screen Edge must cover a complete screen")
                    }
                    let wait = AnimationStyle.lifetime(pluggedIn: connected) + 0.2
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    precondition(!overlay.isVisible, "\(style) must dismiss automatically")
                }
                print("Passed \(style.rawValue): both directions, focus, click-through, dismissal.")
            }
            for index in 0..<25 {
                let style = AnimationStyle.allCases[index % AnimationStyle.allCases.count]
                overlay.show(pluggedIn: index.isMultiple(of: 2), percent: 65, playSound: false, style: style)
                try? await Task.sleep(nanoseconds: 20_000_000)
                precondition(overlay.isVisible, "A cancelled dismissal must not close its replacement")
            }
            overlay.dismiss()
            overlay.dismiss()
            precondition(!overlay.isVisible, "Dismiss must be safe to repeat")
            overlay.show(pluggedIn: true, percent: 100, playSound: false, style: .screenEdge)
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            try? await Task.sleep(nanoseconds: 100_000_000)
            precondition(!overlay.isVisible, "Display changes must dismiss stale effects")
            print("Passed 25 rapid cross-style replacements, repeated cleanup, and display-change cleanup.")
            app.terminate(nil)
        }
        app.run()
    }
}
