import XCTest
@testable import StopStutterCore

final class AutomationTests: XCTestCase {
    func testAutomaticModeOnlyFollowsEnabledBundleIdentifiers() {
        let apps = [WatchedApp(bundleIdentifier: "one", name: "First"),
                    WatchedApp(bundleIdentifier: "two", name: "Second", enabled: false)]
        XCTAssertEqual(WatchedApp.matching(apps, running: ["one", "two", "unrelated"]), ["one"])
        XCTAssertTrue(ProtectionMode.automatic.shouldSuppress(matchingApps: ["one"]))
        XCTAssertFalse(ProtectionMode.automatic.shouldSuppress(matchingApps: []))
    }

    func testOffOverridesRunningAppsAndOnWorksWithoutApps() {
        XCTAssertFalse(ProtectionMode.off.shouldSuppress(matchingApps: ["one"]))
        XCTAssertTrue(ProtectionMode.on.shouldSuppress(matchingApps: []))
    }

    func testSleepOverridesEveryMode() {
        for mode in ProtectionMode.allCases {
            XCTAssertFalse(mode.shouldSuppress(matchingApps: ["one"], sleeping: true))
        }
    }

    func testRemovingOrDisablingLastRunningAppEndsAutomaticProtection() {
        var apps = [WatchedApp(bundleIdentifier: "client", name: "Client")]
        XCTAssertFalse(WatchedApp.matching(apps, running: ["client"]).isEmpty)
        apps[0].enabled = false
        XCTAssertTrue(WatchedApp.matching(apps, running: ["client"]).isEmpty)
        XCTAssertTrue(WatchedApp.matching([], running: ["client"]).isEmpty)
    }

    func testStreamingPresetsMatchVendorBundleIdentifiers() {
        // Vendor app metadata, not display names or launcher/background-process IDs.
        let clients: Set<String> = ["com.nvidia.gfnpc.mall", "tv.parsec.www", "com.valvesoftware.SteamLink17"]
        XCTAssertEqual(WatchedApp.matching(WatchedApp.suggestions, running: clients), clients)
        XCTAssertTrue(WatchedApp.matching(WatchedApp.suggestions, running: ["com.valvesoftware.steam", "com.apple.Safari"]).isEmpty)
    }

    func testSuggestionsPreserveDisabledAndCustomRulesWithoutDuplicates() {
        var disabled = WatchedApp.suggestions[0]
        disabled.enabled = false
        let custom = WatchedApp(bundleIdentifier: "custom.client", name: "My client")
        let saved = [disabled, custom]
        let available = WatchedApp.availableSuggestions(in: saved)
        XCTAssertFalse(available.contains { $0.id == disabled.id })
        XCTAssertEqual(Set(available.map(\.id)).count, available.count)
        XCTAssertEqual(saved, [disabled, custom])
        XCTAssertTrue(WatchedApp.availableSuggestions(in: WatchedApp.suggestions).isEmpty)
        XCTAssertEqual(WatchedApp.availableSuggestions(in: []), WatchedApp.suggestions)
    }

    func testSelectedAppsSurvivePersistenceIncludingEmptySelection() throws {
        let apps = [WatchedApp(bundleIdentifier: "custom.client", name: "Custom Client", path: "/Applications/Custom Client.app")]
        XCTAssertEqual(try JSONDecoder().decode([WatchedApp].self, from: JSONEncoder().encode(apps)), apps)
        XCTAssertEqual(try JSONDecoder().decode([WatchedApp].self, from: JSONEncoder().encode([WatchedApp]())), [])
    }
}
