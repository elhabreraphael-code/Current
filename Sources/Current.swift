import AppKit
import SwiftUI
import IOKit.ps

// Disambiguate the classic property wrapper from the newer SDK macro.
typealias ViewState<Value> = SwiftUI.State<Value>

let accent = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(red: 0.43, green: 0.74, blue: 0.59, alpha: 1)
        : NSColor(red: 0.19, green: 0.53, blue: 0.39, alpha: 1)
})

@MainActor
final class PowerMonitor: ObservableObject {
    @Published var snapshot: PowerSnapshot?
    var onTransition: ((Bool) -> Void)?
    private var transitions = PowerTransitions()
    private var source: CFRunLoopSource?
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?

    init() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in monitor.refresh() }
        }, context)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.transitions.reset()
                self?.refresh()
            }
        }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.transitions.reset() } }
    }

    func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            snapshot = nil
            return
        }
        let value = sources.compactMap { source -> PowerSnapshot? in
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
                    as? [String: Any] else { return nil }
            return PowerSnapshot.parse(description)
        }.first
        snapshot = value
        if let plugged = transitions.receive(value) { onTransition?(plugged) }
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        for observer in [wakeObserver, sleepObserver].compactMap({ $0 }) {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        source = nil
    }
}

@MainActor
final class Preferences: ObservableObject {
    @Published var animations: Bool { didSet { save() } }
    @Published var sound: Bool { didSet { save() } }
    @Published var percentage: Bool { didSet { save() } }
    @Published var style: AnimationStyle { didSet { save() } }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = defaults
        d.register(defaults: ["animations": true, "sound": false, "percentage": false])
        animations = d.bool(forKey: "animations")
        sound = d.bool(forKey: "sound")
        percentage = d.bool(forKey: "percentage")
        style = AnimationStyle(rawValue: d.string(forKey: "animationStyle") ?? "") ?? .connector
    }
    private func save() {
        let d = defaults
        d.set(animations, forKey: "animations")
        d.set(sound, forKey: "sound")
        d.set(percentage, forKey: "percentage")
        d.set(style.rawValue, forKey: "animationStyle")
    }
}

struct ConnectionGlyph: View {
    let connected: Bool
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().fill(connected ? accent.opacity(0.10) : Color.secondary.opacity(0.06))
            Circle().stroke(connected ? accent.opacity(0.20) : Color.secondary.opacity(0.12), lineWidth: 1)
            HStack(spacing: connected ? 1 : 11) {
                HStack(spacing: 0) {
                    Capsule().fill(connected ? accent : Color.secondary.opacity(0.55)).frame(width: 15, height: 4)
                    RoundedRectangle(cornerRadius: 4).fill(connected ? accent : Color.secondary.opacity(0.55))
                        .frame(width: 15, height: 19)
                }
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 4).fill(connected ? accent : Color.secondary.opacity(0.55))
                        .frame(width: 15, height: 19)
                    Capsule().fill(connected ? accent : Color.secondary.opacity(0.55)).frame(width: 15, height: 4)
                }
            }
            .scaleEffect(compact ? 0.65 : 1)
        }
        .frame(width: compact ? 46 : 98, height: compact ? 46 : 98)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: connected ? 0.55 : 0.7, dampingFraction: 0.88), value: connected)
        .accessibilityHidden(true)
    }
}

struct PowerHUD: View {
    let pluggedIn: Bool
    let percent: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var connected: Bool
    @ViewState private var visible = false
    init(pluggedIn: Bool, percent: Int?) {
        self.pluggedIn = pluggedIn
        self.percent = percent
        _connected = ViewState(initialValue: !pluggedIn)
    }
    var body: some View {
        HStack(spacing: 14) {
            ConnectionGlyph(connected: connected, compact: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(pluggedIn ? "Power connected" : "Power disconnected")
                    .font(.system(size: 14, weight: .semibold))
                Text(pluggedIn ? "A little energy. Carry on." : "Back to battery. Carry on.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let percent {
                Text("\(percent)%").font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.13), radius: 12, y: 5)
        .padding(16)
        .opacity(visible ? 1 : 0)
        .offset(y: visible || reduceMotion ? 0 : -8)
        .task {
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.3)) { visible = true }
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            connected = pluggedIn
            try? await Task.sleep(nanoseconds: pluggedIn ? 1_800_000_000 : 1_300_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { visible = false }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PreferenceRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    @Binding var value: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(.secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(title, isOn: $value).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(accent)
                .accessibilityLabel(title).accessibilityHint(subtitle)
        }.padding(.horizontal, 16).padding(.vertical, 13)
    }
}

struct MainView: View {
    @ObservedObject var monitor: PowerMonitor
    @ObservedObject var preferences: Preferences
    let preview: (Bool) -> Void
    @ViewState private var connected = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollView {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "bolt.fill").font(.system(size: 21, weight: .medium)).foregroundStyle(accent)
                    .frame(width: 43, height: 43).background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current").font(.system(size: 20, weight: .semibold))
                    Text("A small moment for your Mac.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(monitor.snapshot != nil ? accent : Color.secondary).frame(width: 5, height: 5)
                    Text(monitor.snapshot.map { "\($0.percent)% · \($0.status)" } ?? "Battery unavailable")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.primary.opacity(0.035), in: Capsule())
                .accessibilityLabel(monitor.snapshot.map { "Battery: \($0.percent) percent, \($0.status)" } ?? "Battery unavailable")
            }
            .padding(.bottom, 22)

            HStack(spacing: 8) {
                ForEach(AnimationStyle.allCases) { style in
                    Button { preferences.style = style } label: {
                        VStack(spacing: 7) {
                            Image(systemName: style.symbol).font(.system(size: 18, weight: .light))
                            Text(style.rawValue).font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity).frame(height: 65)
                        .foregroundStyle(preferences.style == style ? accent : .secondary)
                        .background(preferences.style == style ? accent.opacity(0.10) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(preferences.style == style ? accent.opacity(0.45) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.rawValue)
                    .accessibilityValue(preferences.style == style ? "Selected" : "Not selected")
                    .help(style.detail)
                }
            }.padding(.bottom, 14)

            VStack(spacing: 0) {
                HStack {
                    Text(preferences.style.rawValue.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "sparkle").font(.system(size: 13)).foregroundStyle(accent.opacity(0.7))
                }
                .padding(.horizontal, 22).padding(.top, 19)
                Spacer(minLength: 18)
                StyleIllustration(style: preferences.style, connected: connected)
                    .frame(height: 78)
                Text(connected ? "Quietly connected." : "Gently disconnected.")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .padding(.top, 12)
                Text(connected ? "A little energy. A subtle hello." : "A softer goodbye. Back to your flow.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).padding(.top, 7)
                Spacer(minLength: 23)
                Picker("Preview power state", selection: $connected) {
                    Text("Plug in").tag(true)
                    Text("Unplug").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden().tint(accent).frame(width: 212)
                .padding(.bottom, 20)
            }
            .frame(height: 244)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 22).fill(Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 22).fill(
                    LinearGradient(colors: [accent.opacity(connected ? 0.065 : 0.015), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.primary.opacity(0.065), lineWidth: 1))
            .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.4), value: connected)

            HStack {
                Text(preferences.style.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button { preview(connected) } label: {
                    Label("Preview animation", systemImage: "play.fill").font(.system(size: 11, weight: .medium))
                }.buttonStyle(.bordered).controlSize(.small)
                    .help("Show the selected animation on your desktop")
            }.padding(.top, 12).padding(.bottom, 20)

            VStack(spacing: 0) {
                PreferenceRow(symbol: "sparkles", title: "Power animations", subtitle: "A subtle moment when you connect or disconnect.", value: $preferences.animations)
                Divider().padding(.leading, 52)
                PreferenceRow(symbol: "speaker.wave.1", title: "Gentle sound", subtitle: "A soft tone. Even quieter when you unplug.", value: $preferences.sound)
                Divider().padding(.leading, 52)
                PreferenceRow(symbol: "battery.75percent", title: "Battery percentage", subtitle: "Keep your charge visible in the menu bar.", value: $preferences.percentage)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.primary.opacity(0.055), lineWidth: 1))

            HStack(spacing: 5) {
                Image(systemName: "menubar.rectangle").font(.system(size: 11))
                Text("At home in your menu bar.")
                Spacer()
                Text("Made for a quieter Mac.")
            }.font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 20)
        }
        .padding(26)
        }
        .frame(width: 680)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MenuContent: View {
    @ObservedObject var monitor: PowerMonitor
    @ObservedObject var preferences: Preferences
    let open: () -> Void
    let preview: (Bool) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "bolt.circle.fill").font(.system(size: 29)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current").font(.system(size: 14, weight: .semibold))
                    Text(monitor.snapshot?.status ?? "No battery detected").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if let snapshot = monitor.snapshot { Text("\(snapshot.percent)%").font(.system(size: 21, weight: .medium, design: .rounded)).monospacedDigit() }
            }
            if let snapshot = monitor.snapshot {
                ProgressView(value: Double(snapshot.percent), total: 100).tint(accent)
                    .accessibilityLabel("Battery charge")
            }
            Divider()
            Toggle("Power animations", isOn: $preferences.animations).toggleStyle(.switch).controlSize(.small).tint(accent)
            Picker("Animation", selection: $preferences.style) {
                ForEach(AnimationStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            HStack {
                Button("Preview plug in") { preview(true) }
                Button("Preview unplug") { preview(false) }
            }.controlSize(.small)
            Divider()
            HStack {
                Button("Open Current…", action: open)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }.buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size: 12))
        }.padding(20).frame(width: 288)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let monitor = PowerMonitor()
    let preferences = Preferences()
    let overlay = OverlayController()
    var statusItem: NSStatusItem!
    var window: NSWindow?
    var popover: NSPopover!
    var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Current")
        applicationMenu.addItem(withTitle: "About Current", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Hide Current", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit Current", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        menu.addItem(applicationItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleMenu)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuContent(
            monitor: monitor, preferences: preferences,
            open: { [weak self] in self?.showWindow() },
            preview: { [weak self] plugged in self?.preview(plugged) }))
        monitor.onTransition = { [weak self] plugged in
            guard let self, self.preferences.animations else { return }
            self.overlay.show(pluggedIn: plugged, percent: self.monitor.snapshot?.percent, playSound: self.preferences.sound, style: self.preferences.style)
        }
        monitor.$snapshot.combineLatest(preferences.$percentage).sink { [weak self] snapshot, showPercent in
            self?.updateStatus(snapshot, showPercent: showPercent)
        }.store(in: &cancellables)
        preferences.$animations.dropFirst().sink { [weak self] enabled in
            if !enabled { self?.overlay.dismiss() }
        }.store(in: &cancellables)
        if !CommandLine.arguments.contains("--background") { showWindow() }
    }

    private func updateStatus(_ snapshot: PowerSnapshot?, showPercent: Bool) {
        let symbol = snapshot?.pluggedIn == true ? "bolt.fill" : "bolt"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Current")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = showPercent ? snapshot.map { " \($0.percent)%" } ?? " —" : ""
        statusItem.button?.toolTip = snapshot.map { "Current: \($0.percent)% · \($0.status)" } ?? "Current: Battery unavailable"
        statusItem.button?.setAccessibilityLabel(statusItem.button?.toolTip)
    }

    @objc func toggleMenu() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = statusItem.button { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    func preview(_ plugged: Bool) {
        popover.performClose(nil)
        overlay.show(pluggedIn: plugged, percent: monitor.snapshot?.percent, playSound: preferences.sound, style: preferences.style)
    }

    func showWindow() {
        popover?.performClose(nil)
        if window == nil {
            let view = MainView(monitor: monitor, preferences: preferences, preview: { [weak self] in self?.preview($0) })
            let hosting = NSHostingController(rootView: view)
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "Current"
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.setContentSize(NSSize(width: 680, height: min(792, (NSScreen.main?.visibleFrame.height ?? 850) - 40)))
            newWindow.center()
            window = newWindow
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { NSApp.setActivationPolicy(.accessory) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop(); overlay.dismiss() }
}

import Combine

#if !TESTING
@main
struct CurrentApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
#endif
