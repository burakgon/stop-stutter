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
    @Published var helperOutdated = false
    @Published var interfaceState: InterfaceState = .unavailable

    private let client = HelperClient()
    private let defaults = UserDefaults.standard
    private let service = SMAppService.daemon(plistName: ServiceIdentity.daemonPlist)
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var sessionActivity: NSObjectProtocol?
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
        if error != nil { return "Boost needs a quick check. Open Settings to reconnect the helper." }
        switch protectionState {
        case .active: return "Helping your game stream stay smooth and responsive. Enjoy your session."
        case .setup: return "Smoother game streaming starts here. Enable the helper once, then let Boost take care of each session."
        case .starting: return "Getting Boost ready for your session…"
        case .restoring: return "Wrapping up your Boost session…"
        case .checking: return "Checking whether Boost is active. This should only take a moment."
        case .paused: return "Boost is paused. Choose Always on to start now, or Auto to follow your selected apps."
        case .waiting: return "Open a selected app and Boost starts automatically. It stops when your last selected app quits."
        case .attention: return "Open Settings to get Boost ready again."
        }
    }
    var sessionContext: String {
        if protected {
            let session: String
            if mode == .on {
                session = "Always on · you’re in control"
            } else {
                let names = matchingApps.map(\.name).joined(separator: ", ")
                session = names.isEmpty ? "Boost is active on this Mac" : "Boosting \(names)"
            }
            guard let revivals = snapshot?.revivals, revivals > 0 else { return session }
            return "\(session) · \(revivals) AWDL wake-up\(revivals == 1 ? "" : "s") blocked"
        }
        if protectionState == .waiting { return "Auto ready · \(apps.filter(\.enabled).count) apps selected" }
        if protectionState == .paused { return "Paused · automatic Boost is off" }
        return "Moonlight, GeForce NOW, and your favorite streaming apps"
    }
    var availableSuggestions: [WatchedApp] { WatchedApp.availableSuggestions(in: apps) }

    func addSuggested(_ app: WatchedApp) {
        guard availableSuggestions.contains(where: { $0.id == app.id }) else { return }
        apps.append(app)
        saveApps()
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
        // Common modes keep lease renewal running while a menu is open or a window is being resized.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(); self?.requestSync() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        addEvent("Ready to boost", "Your selected apps can start a Boost session automatically.", symbol: "waveform.path")
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
        panel.title = "Choose an app to boost"
        panel.message = "Boost will stay on for as long as a selected app is running."
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
        let previousMode = mode
        mode = .off
        defaults.set(mode.rawValue, forKey: "mode")
        defer { busy = false; suspendedForRemoval = false }
        do {
            // Wait for any earlier suppress request before releasing our lease.
            while syncing { try await Task.sleep(for: .milliseconds(50)) }
            // A reachable helper must confirm that no other session still owns AWDL. An unreachable one, such as an
            // older build that an update replaced, restores AWDL itself when macOS stops it for removal.
            if service.status == .enabled, let state = try? await client.update(suppress: false) {
                guard !state.managing, state.error == nil else {
                    throw ControlError.connectionFailed("Another Boost session is still active or finishing. Try removing the helper once it ends.")
                }
            }
            try await service.unregister()
            client.invalidate()
            snapshot = nil
            helperConnected = false
            helperOutdated = false
            error = nil
            refresh()
            addEvent("Helper removed", "The background helper has been removed.", symbol: "checkmark.circle")
        } catch {
            // A failed removal must not silently leave Boost switched off.
            setMode(previousMode)
            self.error = error.localizedDescription
        }
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
        updateSessionActivity()
        guard !quitting, !suspendedForRemoval else { return }
        guard !syncing else { resync = true; return }
        guard ready else { helperConnected = false; return }
        syncing = true
        let suppress = shouldSuppress
        Task {
            do {
                let result = try await client.update(suppress: suppress)
                snapshot = result
                interfaceState = result.interface
                helperConnected = true
                error = result.error
                if result.protected != previousProtection {
                    let enabled = result.protected
                    let names = matchingApps.map(\.name).joined(separator: ", ")
                    let title = enabled ? "Boost is on" : "Boost is off"
                    let detail = enabled
                        ? (mode == .on ? "Boost is ready for your session. It stays on until you change the mode or quit Stop Stutter." : "\(names.isEmpty ? "A watched app" : names) is running. Enjoy your Boost session.")
                        : "Your Boost session has ended. See you next game."
                    // A session ends only when Boost was released and the interface was verified up. While Boost
                    // is still requested, AWDL briefly reported up is macOS reviving it; the helper corrects that.
                    if enabled || (!suppress && result.interface == .up && result.error == nil) {
                        addEvent(title, detail, symbol: enabled ? "bolt.fill" : "bolt.slash")
                        notify(title, detail)
                        previousProtection = enabled
                    }
                }
                if let message = result.error, message != lastEventError {
                    addEvent("Boost needs attention", message, symbol: "exclamationmark.triangle")
                    notify("Boost needs attention", message)
                }
                lastEventError = result.error
                let outdated = (result.helperRevision ?? 0) < ServiceIdentity.helperRevision
                if outdated && !helperOutdated {
                    addEvent("Helper update pending", Self.helperUpdateAdvice, symbol: "arrow.triangle.2.circlepath")
                }
                helperOutdated = outdated
            } catch {
                helperConnected = false
                self.error = Self.unavailableMessage(for: error)
                // Invalidating releases this app's lease at once, so only a broken connection is replaced.
                if !(error is HelperTimeout) { client.invalidate() }
            }
            syncing = false
            if resync { resync = false; requestSync() }
        }
    }

    /// An update that replaces the helper's executable leaves the old process failing the code-signature check
    /// until it restarts. Helpers from 0.1.1 on restart within seconds; a 0.1.0 helper needs help once.
    private static func unavailableMessage(for error: Error) -> String {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain && error.code == NSXPCConnectionCodeSigningRequirementFailure {
            return "The helper still running is from the previous version. It normally restarts within a few seconds. If this message stays, use Remove Helper and then Enable Helper, or restart your Mac."
        }
        return "The helper is unavailable. Check its approval in System Settings. \(error.localizedDescription)"
    }

    static let helperUpdateAdvice = "This version includes a faster helper. Restart your Mac, or use Remove Helper and then Enable Helper in Settings, to start using it."

    /// App Nap can delay the heartbeat timer long enough for the helper's lease to expire mid-session,
    /// which would bring AWDL back. Hold an activity only while Boost is requested.
    private func updateSessionActivity() {
        let requested = ready && shouldSuppress
        if requested, sessionActivity == nil {
            sessionActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "Renewing the Boost lease during a session")
        } else if !requested, let activity = sessionActivity {
            ProcessInfo.processInfo.endActivity(activity)
            sessionActivity = nil
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
