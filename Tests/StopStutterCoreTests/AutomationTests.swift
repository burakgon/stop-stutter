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

    func testSelectedAppsSurvivePersistenceIncludingEmptySelection() throws {
        let apps = [WatchedApp(bundleIdentifier: "custom.client", name: "Custom Client", path: "/Applications/Custom Client.app")]
        XCTAssertEqual(try JSONDecoder().decode([WatchedApp].self, from: JSONEncoder().encode(apps)), apps)
        XCTAssertEqual(try JSONDecoder().decode([WatchedApp].self, from: JSONEncoder().encode([WatchedApp]())), [])
    }
}
