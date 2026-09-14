import Foundation

@main
struct PreferencesTests {
    @MainActor static func main() {
        let suite = "Current.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        precondition(AnimationStyle.allCases.count == 5)
        precondition(preferences.style == .connector)
        precondition(preferences.animations && !preferences.sound && !preferences.percentage)
        for style in AnimationStyle.allCases {
            precondition(!style.symbol.isEmpty && !style.detail.isEmpty)
            preferences.style = style
            precondition(Preferences(defaults: defaults).style == style, "Style must persist")
        }
        preferences.sound = true
        preferences.percentage = true
        preferences.animations = false
        let restored = Preferences(defaults: defaults)
        precondition(restored.sound && restored.percentage && !restored.animations)
        defaults.set("Removed style", forKey: "animationStyle")
        precondition(Preferences(defaults: defaults).style == .connector, "Unknown styles must safely fall back")
        precondition(AnimationStyle.lifetime(pluggedIn: false) < AnimationStyle.lifetime(pluggedIn: true))
        print("Passed all five style persistence checks, defaults, migration fallback, and preference restoration.")
    }
}
