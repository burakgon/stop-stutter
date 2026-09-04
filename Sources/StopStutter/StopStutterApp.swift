import AppKit
import SwiftUI
import UserNotifications

@main
struct StopStutterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Stop Stutter", id: "main") {
            MainView(model: model)
                .onAppear { delegate.model = model }
        }
        .defaultSize(width: 980, height: 780)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Stop Stutter") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(string: "Reduce AWDL-related Wi-Fi stutter while you stream.\nOpen source · MIT License\ngithub.com/burakgon/stop-stutter")
                    ])
                }
            }
        }

        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.protected ? "waveform.path" : "waveform.path.ecg")
                .accessibilityLabel(model.protected ? "Stop Stutter: protection on" : "Stop Stutter")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var model: AppModel?
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        Task {
            await model?.prepareToQuit()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
