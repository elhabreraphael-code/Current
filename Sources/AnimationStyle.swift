import Foundation

enum AnimationStyle: String, CaseIterable, Identifiable {
    case connector = "Connector"
    case screenEdge = "Screen Edge"
    case halo = "Halo"
    case ripple = "Ripple"
    case underline = "Underline"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .connector: return "powerplug"
        case .screenEdge: return "rectangle.inset.filled"
        case .halo: return "circle.dotted.circle"
        case .ripple: return "water.waves"
        case .underline: return "minus"
        }
    }
    var detail: String {
        switch self {
        case .connector: return "A familiar little connection."
        case .screenEdge: return "A soft glow around your whole screen."
        case .halo: return "A quiet circle of energy."
        case .ripple: return "A gentle ripple, then stillness."
        case .underline: return "A fine line. Just enough."
        }
    }
    static func lifetime(pluggedIn: Bool) -> Double { pluggedIn ? 2.65 : 2.15 }
}
