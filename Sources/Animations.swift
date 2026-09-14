import AppKit
import SwiftUI

/// The same shapes are used by the live effect and the settings illustration.
struct EnergyMark: View {
    let style: AnimationStyle
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                switch style {
                case .connector:
                    EmptyView()
                case .screenEdge:
                    let border = RoundedRectangle(cornerRadius: min(24, side * 0.12))
                    border.trim(from: 0, to: progress)
                        .stroke(color.opacity(0.25), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .blur(radius: 7)
                    border.trim(from: 0, to: progress)
                        .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                case .halo:
                    Circle().stroke(color.opacity(0.1), lineWidth: 1)
                    Circle().trim(from: 0, to: progress)
                        .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle().trim(from: 0, to: progress)
                        .stroke(color.opacity(0.24), lineWidth: 9).blur(radius: 7)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: side * 0.26, weight: .light))
                        .foregroundStyle(color.opacity(0.4 + progress * 0.6))
                        .scaleEffect(0.9 + progress * 0.1)
                case .ripple:
                    ForEach(0..<3) { index in
                        let phase = max(0, min(1, progress * 1.5 - Double(index) * 0.23))
                        Circle().stroke(color.opacity((1 - phase * 0.75) * 0.6), lineWidth: 1.2)
                            .scaleEffect(0.2 + phase * 0.8)
                    }
                    Circle().fill(color.opacity(0.7)).frame(width: 5, height: 5)
                case .underline:
                    Capsule().fill(color.opacity(0.10)).frame(height: 2)
                    Capsule().fill(color.opacity(0.75)).frame(height: 2)
                        .scaleEffect(x: max(0.001, progress), y: 1)
                    Capsule().fill(color.opacity(0.3)).frame(height: 5)
                        .scaleEffect(x: max(0.001, progress), y: 1).blur(radius: 5)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }
}

struct StyleIllustration: View {
    let style: AnimationStyle
    let connected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if style == .connector {
                ConnectionGlyph(connected: connected).scaleEffect(0.78)
            } else {
                ZStack {
                    if style == .screenEdge {
                        RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.025))
                        RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    EnergyMark(style: style, progress: connected ? 1 : 0.18,
                               color: connected ? accent : Color.secondary.opacity(0.65))
                        .padding(style == .screenEdge ? 4 : 0)
                }.frame(width: style == .screenEdge || style == .underline ? 144 : 72, height: 72)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: connected ? 0.7 : 0.9), value: connected)
    }
}

struct AmbientEffect: View {
    let style: AnimationStyle
    let pluggedIn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var progress: Double
    @ViewState private var visible = false

    init(style: AnimationStyle, pluggedIn: Bool) {
        self.style = style
        self.pluggedIn = pluggedIn
        _progress = ViewState(initialValue: pluggedIn ? 0 : 1)
    }

    var body: some View {
        EnergyMark(style: style, progress: progress,
                   color: pluggedIn ? Color(red: 0.57, green: 0.86, blue: 0.72) : Color(red: 0.7, green: 0.77, blue: 0.73))
            .padding(style == .screenEdge ? 5 : 16)
            .opacity(visible ? (pluggedIn ? 0.9 : 0.48) : 0)
            .ignoresSafeArea()
            .task {
                if reduceMotion { progress = 1 }
                withAnimation(.easeOut(duration: 0.2)) { visible = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: pluggedIn ? 1.35 : 1.4)) {
                        progress = pluggedIn ? 1 : 0
                    }
                }
                try? await Task.sleep(nanoseconds: pluggedIn ? 1_850_000_000 : 1_420_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) { visible = false }
            }
    }
}

/// One nonactivating, click-through window at a time. Every replacement cancels
/// both the previous view task and its dismissal, even during rapid cable changes.
@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var sound: NSSound?
    private var screenObserver: NSObjectProtocol?
    var isVisible: Bool { panel?.isVisible == true }
    var activeFrame: NSRect? { panel?.frame }
    var ignoresMouseEvents: Bool { panel?.ignoresMouseEvents == true }

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.dismiss() } }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    static func frame(for style: AnimationStyle, screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        switch style {
        case .connector:
            return NSRect(x: visible.midX - 191, y: visible.maxY - 132, width: 382, height: 120)
        case .screenEdge:
            return screen.frame
        case .halo:
            return NSRect(x: visible.midX - 78, y: visible.midY - 78, width: 156, height: 156)
        case .ripple:
            return NSRect(x: visible.midX - 110, y: visible.minY + 36, width: 220, height: 220)
        case .underline:
            return NSRect(x: visible.midX - 170, y: visible.minY + 16, width: 340, height: 48)
        }
    }

    func show(pluggedIn: Bool, percent: Int?, playSound: Bool, style: AnimationStyle = .connector) {
        dismiss()
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let panel = NSPanel(contentRect: Self.frame(for: style, screen: screen),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        if style == .connector {
            panel.contentView = NSHostingView(rootView: PowerHUD(pluggedIn: pluggedIn, percent: percent))
        } else {
            panel.contentView = NSHostingView(rootView: AmbientEffect(style: style, pluggedIn: pluggedIn))
        }
        // A full-screen border uses physical screen bounds, including behind the menu bar.
        panel.setFrame(Self.frame(for: style, screen: screen), display: false)
        self.panel = panel
        panel.orderFrontRegardless()
        if playSound, let path = Bundle.main.path(forResource: pluggedIn ? "Connect" : "Disconnect", ofType: "wav") {
            sound = NSSound(contentsOfFile: path, byReference: false)
            sound?.volume = pluggedIn ? 0.35 : 0.15
            sound?.play()
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(AnimationStyle.lifetime(pluggedIn: pluggedIn) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel?.close()
        panel = nil
        sound?.stop()
        sound = nil
    }
}
