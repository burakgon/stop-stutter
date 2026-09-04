import AppKit
import ServiceManagement
import StopStutterCore
import SwiftUI

private enum Page: String, CaseIterable, Identifiable {
    case overview = "Overview", applications = "Applications", activity = "Activity", settings = "Settings"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: return "waveform.path"
        case .applications: return "square.stack.3d.up"
        case .activity: return "clock.arrow.circlepath"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var page: Page = .overview
    @State private var showingExplanation = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    switch page {
                    case .overview: overview
                    case .applications: applications
                    case .activity: activity
                    case .settings: settings
                    }
                }
                .padding(32)
                .frame(maxWidth: 960, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background {
                ZStack(alignment: .topTrailing) {
                    Color(nsColor: .windowBackgroundColor)
                    Ellipse().fill(Color.mint.opacity(colorScheme == .dark ? 0.07 : 0.05))
                        .frame(width: 600, height: 380).blur(radius: 80).offset(x: 140, y: -150)
                }
            }
        }
        .frame(minWidth: 880, minHeight: 680)
        .tint(.mint)
        .sheet(isPresented: $showingExplanation) { AWDLExplanationView() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                BrandMark(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stop Stutter").font(.system(size: 15, weight: .semibold))
                    Text("Game streaming, smoother.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 22).padding(.top, 48).padding(.bottom, 34)

            VStack(spacing: 6) {
                ForEach(Page.allCases) { item in
                    Button { page = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).frame(width: 18)
                            Text(item.rawValue).fontWeight(page == item ? .semibold : .regular)
                            Spacer()
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(page == item ? Color.primary : .secondary)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background {
                            if page == item {
                                RoundedRectangle(cornerRadius: 11).fill(.primary.opacity(0.07))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }.padding(.horizontal, 12)
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle().fill(model.ready ? Color.mint : Color.secondary.opacity(0.5)).frame(width: 6, height: 6)
                    Text(model.ready ? "Ready to boost" : "One-time setup needed").font(.system(size: 11, weight: .medium))
                }
                Text("Native. Automatic. Open source.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                Link("Open source ↗", destination: URL(string: "https://github.com/burakgon/stop-stutter")!)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(width: 210)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(page.rawValue).font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(headerSubtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Label(model.protectionState.badge, systemImage: stateSymbol)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(stateColor)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .modifier(GlassSurface(cornerRadius: 24))
            Button { showingExplanation = true } label: {
                Image(systemName: "questionmark.circle").font(.system(size: 21, weight: .regular))
                    .frame(width: 32, height: 32).contentShape(Circle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("How does Boost work?")
            .accessibilityLabel("How does Boost work? Learn why game streams stutter and how Boost helps")
        }
    }

    private var stateColor: Color { model.protectionState.color }
    private var stateSymbol: String { model.protectionState.symbol }

    private var headerSubtitle: String {
        switch page {
        case .overview: return "Smoother game streaming on Mac."
        case .applications: return "Choose which apps automatically start Boost."
        case .activity: return "Your recent Boost sessions, at a glance."
        case .settings: return "Control the helper, notifications, and startup."
        }
    }

    private var overview: some View {
        VStack(spacing: 20) {
            hero
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Auto-boost your apps").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button("Manage", systemImage: "arrow.up.right") { page = .applications }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if model.apps.isEmpty {
                    Button("Add your first application", systemImage: "plus") { model.addApplication() }
                        .buttonStyle(.bordered)
                } else {
                    ForEach(Array(model.apps.prefix(3))) { app in appRow(app, removable: false) }
                }
            }.padding(20).modifier(PanelSurface())
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 7) {
                        Image(systemName: stateSymbol).font(.system(size: 11, weight: .bold))
                        Text(model.protectionState.label)
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                    }
                    .foregroundStyle(stateColor)
                    Text(model.statusTitle)
                        .font(.system(size: 38, weight: .bold, design: .rounded)).tracking(-0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.statusDetail)
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                StateEmblem(state: model.protectionState, color: stateColor, symbol: stateSymbol)
                    .frame(width: 106, height: 116)
                    .accessibilityHidden(true)
            }
            Label(model.sessionContext, systemImage: model.mode == .automatic ? "app.badge" : "hand.raised")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Rectangle().fill(.primary.opacity(0.07)).frame(height: 1)
            HStack {
                if !model.ready {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.helperStatus == .requiresApproval ? "One approval to go" : "One-time setup")
                            .font(.system(size: 12, weight: .medium))
                        Text("macOS will ask you to approve the helper.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { Task { await model.enableHelper() } } label: {
                        Label(model.helperStatus == .requiresApproval ? "Approve Helper" : "Enable Helper", systemImage: "bolt.fill")
                            .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 3)
                    }
                    .buttonStyle(PrimaryGlassButton()).disabled(model.busy)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Boost mode").font(.system(size: 12, weight: .semibold))
                        Text("Automatic, or whenever you want.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    modePicker.frame(width: 260)
                }
            }
        }
        .padding(26)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [stateColor.opacity(model.protected ? 0.18 : 0.045), stateColor.opacity(0.015), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .modifier(PanelSurface(radius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(stateColor.opacity(model.protected ? 0.45 : 0.14), lineWidth: 1))
    }

    private var applications: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Boost follows your selected apps, even in the background.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Add App", systemImage: "plus") { model.addApplication() }
                    .buttonStyle(PrimaryGlassButton())
            }
            VStack(spacing: 18) {
                if model.apps.isEmpty {
                    ContentUnavailableView("Your next session starts here", systemImage: "app.dashed",
                                           description: Text("Add Moonlight, GeForce NOW, or another app you stream with."))
                }
                ForEach(model.apps) { app in appRow(app, removable: true) }
            }.padding(22).modifier(PanelSurface())
            if !model.availableSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("More apps to boost").font(.system(size: 14, weight: .semibold))
                    ForEach(model.availableSuggestions) { app in
                        HStack(spacing: 13) {
                            AppIconView(app: app, model: model).frame(width: 30, height: 30)
                            Text(app.name).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Button("Add", systemImage: "plus") { model.addSuggested(app) }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Add \(app.name)")
                        }
                    }
                }.padding(22).modifier(PanelSurface())
            }
            Label("Auto Boost stops when the last selected app quits. Closing a window may leave the app running.", systemImage: "info.circle")
                .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("This session only · stored in memory · no telemetry")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { model.clearActivity() }.disabled(model.events.isEmpty)
            }
            VStack(alignment: .leading, spacing: 24) {
                if model.events.isEmpty {
                    ContentUnavailableView("All quiet", systemImage: "clock", description: Text("Your Boost sessions will appear here."))
                }
                ForEach(model.events) { event in
                    HStack(alignment: .top, spacing: 15) {
                        Image(systemName: event.symbol).foregroundStyle(.mint).frame(width: 24).padding(.top, 3)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.title).font(.system(size: 13, weight: .semibold))
                            Text(event.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.date, style: .time).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                    }
                }
            }.padding(22).modifier(PanelSurface())
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Make yourself at home").font(.system(size: 15, weight: .semibold))
                settingToggle("Launch at login", detail: "Keep Stop Stutter ready in your menu bar.",
                              binding: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                Divider()
                settingToggle("Boost notifications", detail: "A quiet banner when your Boost session starts or ends.",
                              binding: Binding(get: { model.notificationsEnabled }, set: model.setNotifications))
                if model.notificationDenied {
                    Text("Notifications are blocked in System Settings → Notifications → Stop Stutter.")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                }
            }.padding(22).modifier(PanelSurface())
            VStack(alignment: .leading, spacing: 16) {
                Label("Background helper", systemImage: "bolt.fill").font(.system(size: 15, weight: .semibold))
                Text("The helper keeps Boost running during your session and wraps up when it ends. macOS manages its permission.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                HStack {
                    if model.ready || model.helperStatus == .requiresApproval {
                        Button("System Settings", systemImage: "arrow.up.right") { SMAppService.openSystemSettingsLoginItems() }
                        Spacer()
                        Button("Remove Helper", role: .destructive) { Task { await model.removeHelper() } }
                    } else {
                        Button("Enable Helper", systemImage: "bolt.fill") { Task { await model.enableHelper() } }
                            .buttonStyle(PrimaryGlassButton())
                    }
                }.disabled(model.busy)
                if let error = model.error { Text(error).font(.system(size: 11)).foregroundStyle(.orange).textSelection(.enabled) }
            }.padding(22).modifier(PanelSurface())
            HStack {
                Text("Stop Stutter 0.1.0 · MIT License").font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Link("Source & feedback ↗", destination: URL(string: "https://github.com/burakgon/stop-stutter")!)
                    .font(.system(size: 11))
            }
        }
    }

    private var modePicker: some View {
        Picker("Boost", selection: Binding(get: { model.mode }, set: model.setMode)) {
            ForEach(ProtectionMode.allCases) { mode in Text(mode.title).tag(mode) }
        }.pickerStyle(.segmented).labelsHidden().controlSize(.large)
    }

    private func appRow(_ app: WatchedApp, removable: Bool) -> some View {
        HStack(spacing: 13) {
            AppIconView(app: app, model: model).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(.system(size: 12, weight: .semibold))
                Text(model.running.contains(app.id) ? "Running" : model.appURL(app) == nil ? "Not installed · ready when you are" : "Waiting for your next session")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            if model.running.contains(app.id) && app.enabled {
                Text("LIVE").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                    .foregroundStyle(.mint).padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.mint.opacity(0.1), in: Capsule())
            }
            Toggle("Watch \(app.name)", isOn: Binding(get: { app.enabled }, set: { model.setEnabled(app, $0) }))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
            if removable {
                Button { model.remove(app) } label: { Image(systemName: "minus.circle").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).help("Remove \(app.name)").accessibilityLabel("Remove \(app.name)")
            }
        }
    }

    private func settingToggle(_ title: String, detail: String, binding: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(title, isOn: binding).toggleStyle(.switch).labelsHidden().controlSize(.small)
        }
    }
}

private struct AppIconView: View {
    let app: WatchedApp
    @ObservedObject var model: AppModel
    private var fallbackSymbol: String {
        switch app.id {
        case "com.moonlight-stream.Moonlight": return "moon.stars.fill"
        case "com.nvidia.gfnpc.mall": return "cloud.fill"
        case "tv.parsec.www": return "desktopcomputer"
        case "com.valvesoftware.SteamLink17": return "gamecontroller.fill"
        default: return "app.fill"
        }
    }
    var body: some View {
        if let url = model.appURL(app) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().interpolation(.high)
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: 20)).foregroundStyle(.mint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        }
    }
}

struct BrandMark: View {
    var size: CGFloat
    var body: some View {
        Image(systemName: "waveform.path")
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(Color(red: 0.64, green: 0.98, blue: 0.84))
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.28, blue: 0.27), Color(red: 0.04, green: 0.10, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.28))
            .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(.white.opacity(0.15), lineWidth: 0.5))
    }
}

private struct StateEmblem: View {
    let state: ProtectionState
    let color: Color
    let symbol: String
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(state == .active ? 0.2 : 0.06))
            Circle().stroke(color.opacity(state == .active ? 0.55 : 0.18), lineWidth: 1.5)
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 34, weight: .medium))
                Text(state == .active ? "ON" : [.setup, .waiting, .paused].contains(state) ? "OFF" : "CHECK")
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).tracking(2)
            }.foregroundStyle(color)
        }
    }
}

extension ProtectionState {
    var color: Color {
        switch self {
        case .active: return .mint
        case .waiting: return .cyan
        case .paused: return .secondary
        case .checking, .starting, .restoring: return .blue
        case .setup, .attention: return .orange
        }
    }
    var symbol: String {
        switch self {
        case .active: return "bolt.fill"
        case .waiting: return "clock.fill"
        case .paused, .setup: return "bolt.slash.fill"
        case .checking, .starting, .restoring: return "arrow.triangle.2.circlepath"
        case .attention: return "exclamationmark.circle.fill"
        }
    }
    var badge: String {
        switch self {
        case .active: return "BOOST ON"
        case .waiting, .paused, .setup: return "BOOST OFF"
        case .checking, .starting, .restoring: return "CHECKING STATUS"
        case .attention: return "NEEDS ATTENTION"
        }
    }
}

private struct PanelSurface: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content.background(.background.opacity(0.35), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(.primary.opacity(0.07), lineWidth: 1))
    }
}

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 16
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) { content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius)) }
        else { content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius)) }
    }
}

struct PrimaryGlassButton: PrimitiveButtonStyle {
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) { Button(configuration).buttonStyle(.glassProminent).tint(.mint) }
        else { Button(configuration).buttonStyle(.borderedProminent).tint(.mint) }
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                BrandMark(size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Stop Stutter").font(.system(size: 13, weight: .semibold))
                    Label(model.protectionState.badge, systemImage: model.protectionState.symbol)
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(model.protectionState.color)
                }
            }
            if model.ready {
                Picker("Boost", selection: Binding(get: { model.mode }, set: model.setMode)) {
                    ForEach(ProtectionMode.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
                Text(model.statusDetail)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Button("Open Stop Stutter") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }.buttonStyle(.plain).font(.system(size: 11))
        }.padding(20).frame(width: 290).tint(.mint)
    }
}
