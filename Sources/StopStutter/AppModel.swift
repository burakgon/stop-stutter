import AppKit
import Combine
import ServiceManagement
import StopStutterCore
import UniformTypeIdentifiers
import UserNotifications

struct ActivityEvent: Identifiable {
    let id = UUID()
    let date = Date()
    let title: String
    let detail: String
    let symbol: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var apps: [WatchedApp] = []
    @Published var mode: ProtectionMode = .automatic
    @Published var running: Set<String> = []
    @Published var snapshot: HelperSnapshot?
    @Published var helperStatus: SMAppService.Status = .notRegistered
    @Published var error: String?
    @Published var events: [ActivityEvent] = []
    @Published var notificationsEnabled = true
    @Published var notificationDenied = false
    @Published var launchAtLogin = false
    @Published var busy = false
    @Published var helperConnected = false
    @Published var interfaceState: InterfaceState = .unavailable

    private let client = HelperClient()
    private let defaults = UserDefaults.standard
    private let service = SMAppService.daemon(plistName: ServiceIdentity.daemonPlist)
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var syncing = false
    private var resync = false
    private var sleeping = false
    private var quitting = false
    private var suspendedForRemoval = false
    private var previousProtection = false
    private var lastEventError: String?

    var matchingIDs: Set<String> { WatchedApp.matching(apps, running: running) }
    var matchingApps: [WatchedApp] { apps.filter { matchingIDs.contains($0.id) } }
    var shouldSuppress: Bool {
        !quitting && !suspendedForRemoval && mode.shouldSuppress(matchingApps: matchingIDs, sleeping: sleeping)
    }
    var protected: Bool { helperConnected && snapshot?.protected == true }
    var ready: Bool { helperStatus == .enabled }
    var protectionState: ProtectionState {
        .resolve(ready: ready, connected: helperConnected, requested: shouldSuppress,
                 mode: mode, snapshot: snapshot, hasError: error != nil)
    }
    var statusTitle: String {
        protectionState.title
    }
    var statusDetail: String {
        if let error { return error }
        if protected {
            return "AWDL is held off to reduce Wi-Fi latency spikes, video hitching, and audio interruptions caused by AWDL."
        }
        if !ready { return "Reduce AWDL-related Wi-Fi stutter in Moonlight, Punktfunk, and other streaming apps. Enable the helper to get started." }
        if protectionState == .starting { return "Waiting for the helper to confirm AWDL is off. Protection is not active yet." }
        if protectionState == .restoring { return "Your session ended. The helper is turning AWDL back on so Apple sharing can resume." }
        if protectionState == .checking { return "Confirming the helper’s current status before reporting whether protection is active." }
        if mode == .off { return "Automatic protection is paused. Choose Always on to hold AWDL off now, or Auto to follow your streaming apps." }
        return "No watched app is running. Open one to reduce AWDL-related stutter automatically; quit it to restore Apple sharing."
    }
    var sessionContext: String {
        if protected {
            if mode == .on { return "Manual session · stays on until you change the mode or quit" }
            let names = matchingApps.map(\.name).joined(separator: ", ")
            return names.isEmpty ? "Another Stop Stutter session is protecting this Mac" : "Active for \(names) · ends when the last watched app quits"
        }
        if protectionState == .waiting { return "Auto is armed · \(apps.filter(\.enabled).count) apps watched" }
        if protectionState == .paused { return "Auto is paused · opening a watched app will not start protection" }
        return "Protection ON means AWDL OFF. Your normal Wi-Fi stays on."
    }

    init() {
        if let data = defaults.data(forKey: "watchedApps"),
           let saved = try? JSONDecoder().decode([WatchedApp].self, from: data) { apps = saved }
        else { apps = WatchedApp.suggestions }
        mode = defaults.string(forKey: "mode") == ProtectionMode.off.rawValue ? .off : .automatic
        notificationsEnabled = defaults.object(forKey: "notifications") as? Bool ?? true
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    if name == NSWorkspace.didWakeNotification || name == NSWorkspace.sessionDidBecomeActiveNotification {
                        self?.sleeping = false
                    }
                    self?.refresh()
                    self?.requestSync()
                }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.sleeping = true; self?.requestSync() }
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(); self?.requestSync() }
        }
        addEvent("Ready to listen", "Watching application launches and quits on this Mac.", symbol: "waveform.path")
        requestSync()
        Task { await refreshNotificationPermission() }
    }

    func refresh() {
        running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        helperStatus = service.status
        launchAtLogin = SMAppService.mainApp.status == .enabled
        interfaceState = (try? SystemAWDLDriver().state()) ?? .unavailable
    }

    func setMode(_ value: ProtectionMode) {
        mode = value
        // A manually forced session must never silently restart after a relaunch.
        defaults.set(value == .off ? value.rawValue : ProtectionMode.automatic.rawValue, forKey: "mode")
        error = nil
        requestSync()
    }

    func setEnabled(_ app: WatchedApp, _ value: Bool) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].enabled = value
        saveApps()
    }

    func remove(_ app: WatchedApp) { apps.removeAll { $0.id == app.id }; saveApps() }

    func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to protect"
        panel.message = "AWDL will be held off for as long as a selected app is running."
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  id != ServiceIdentity.app else {
                error = "Choose an application with a bundle identifier other than Stop Stutter."
                continue
            }
            if let existing = apps.firstIndex(where: { $0.id == id }) {
                apps[existing].enabled = true
                apps[existing].path = url.path
            } else {
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                apps.append(WatchedApp(bundleIdentifier: id, name: name, path: url.path))
            }
        }
        saveApps()
    }

    func appURL(_ app: WatchedApp) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) { return url }
        guard let path = app.path, Bundle(path: path)?.bundleIdentifier == app.id else { return nil }
        return URL(fileURLWithPath: path)
    }

    func enableHelper() async {
        busy = true
        defer { busy = false }
        do {
            _ = try PeerTrust.requirement(for: ServiceIdentity.helper)
            guard Bundle.main.bundleURL.path.hasPrefix("/Applications/") else {
                throw ControlError.connectionFailed("Move Stop Stutter to Applications, then open it from there to enable the helper.")
            }
            if service.status != .enabled && service.status != .requiresApproval { try service.register() }
            refresh()
            if helperStatus == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            error = nil
            if notificationsEnabled { await requestNotificationPermission() }
            requestSync()
        } catch { self.error = error.localizedDescription }
    }

    func removeHelper() async {
        busy = true
        suspendedForRemoval = true
        mode = .off
        defaults.set(mode.rawValue, forKey: "mode")
        defer { busy = false; suspendedForRemoval = false }
        do {
            // Wait for any earlier suppress request before releasing our lease.
            while syncing { try await Task.sleep(for: .milliseconds(50)) }
            if service.status == .enabled {
                let state = try await client.update(suppress: false)
                guard !state.managing, state.error == nil else {
                    throw ControlError.connectionFailed("The helper is still protecting another session or restoring AWDL. Try removing it once recovery finishes.")
                }
            }
            try await service.unregister()
            client.invalidate()
            snapshot = nil
            helperConnected = false
            error = nil
            refresh()
            addEvent("Helper removed", "Background AWDL control is disabled.", symbol: "checkmark.circle")
        } catch { self.error = error.localizedDescription }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { self.error = error.localizedDescription }
    }

    func setNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        defaults.set(enabled, forKey: "notifications")
        if enabled { Task { await requestNotificationPermission() } }
    }

    func prepareToQuit() async {
        quitting = true
        timer?.invalidate()
        while syncing { try? await Task.sleep(for: .milliseconds(50)) }
        if service.status == .enabled { _ = try? await client.update(suppress: false) }
        client.invalidate() // Invalidation also releases the lease; expiry is the final fallback.
    }

    func requestSync() {
        guard !quitting, !suspendedForRemoval else { return }
        guard !syncing else { resync = true; return }
        guard ready else { helperConnected = false; return }
        syncing = true
        Task {
            do {
                let result = try await client.update(suppress: shouldSuppress)
                snapshot = result
                interfaceState = result.interface
                helperConnected = true
                error = result.error
                if result.protected != previousProtection {
                    let enabled = result.protected
                    let names = matchingApps.map(\.name).joined(separator: ", ")
                    let title = enabled ? "Protection is on" : "AWDL is back on"
                    let detail = enabled
                        ? (mode == .on ? "Manual protection started. AWDL is held off every second." : "\(names.isEmpty ? "A watched app" : names) is running. AWDL is held off every second.")
                        : "Protection ended. AirDrop and related Continuity features can resume."
                    // Only announce recovery after the interface was verified up.
                    if enabled || (result.interface == .up && result.error == nil) {
                        addEvent(title, detail, symbol: enabled ? "waveform.path" : "wifi")
                        notify(title, detail)
                        previousProtection = enabled
                    }
                }
                if let message = result.error, message != lastEventError {
                    addEvent("AWDL needs attention", message, symbol: "exclamationmark.triangle")
                    notify("AWDL needs attention", message)
                }
                lastEventError = result.error
            } catch {
                helperConnected = false
                self.error = "The helper is unavailable. Check its approval in System Settings. \(error.localizedDescription)"
                client.invalidate()
            }
            syncing = false
            if resync { resync = false; requestSync() }
        }
    }

    func clearActivity() { events.removeAll() }

    private func saveApps() {
        defaults.set(try? JSONEncoder().encode(apps), forKey: "watchedApps")
        refresh()
        requestSync()
    }

    private func addEvent(_ title: String, _ detail: String, symbol: String) {
        events.insert(ActivityEvent(title: title, detail: detail, symbol: symbol), at: 0)
        if events.count > 50 { events.removeLast(events.count - 50) }
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await refreshNotificationPermission()
    }

    private func refreshNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationDenied = settings.authorizationStatus == .denied
    }

    private func notify(_ title: String, _ body: String) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Quiet by default: do not play a sound over the user's stream.
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
