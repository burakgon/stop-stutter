import XCTest
@testable import StopStutterCore

final class ProtectionStateTests: XCTestCase {
    private func resolve(ready: Bool = true, connected: Bool = true, requested: Bool = false,
                         mode: ProtectionMode = .automatic, snapshot: HelperSnapshot? = nil,
                         error: Bool = false) -> ProtectionState {
        .resolve(ready: ready, connected: connected, requested: requested, mode: mode,
                 snapshot: snapshot, hasError: error)
    }

    func testChoosingOnCannotClaimProtectionBeforeConfirmation() {
        XCTAssertEqual(resolve(requested: true, mode: .on), .starting)
        XCTAssertEqual(resolve(ready: false, requested: true, mode: .on), .setup)
        XCTAssertEqual(resolve(connected: false, requested: true, mode: .on), .checking)
    }

    func testVerifiedDownWithLiveOwnershipIsActive() {
        let snapshot = HelperSnapshot(interface: .down, managing: true, leaseCount: 1, error: nil)
        XCTAssertEqual(resolve(requested: true, snapshot: snapshot), .active)
    }

    func testStaleProtectedSnapshotCannotHideConnectionLossOrErrors() {
        let snapshot = HelperSnapshot(interface: .down, managing: true, leaseCount: 1, error: nil)
        XCTAssertEqual(resolve(connected: false, snapshot: snapshot), .checking)
        XCTAssertEqual(resolve(snapshot: snapshot, error: true), .attention)
    }

    func testInterfaceDownWithoutOwnershipIsNotProtection() {
        let snapshot = HelperSnapshot(interface: .down, managing: false, leaseCount: 0, error: nil)
        XCTAssertEqual(resolve(snapshot: snapshot), .waiting)
    }

    func testWaitingAndPausedAreDifferentStatesButBothSayOff() {
        XCTAssertEqual(resolve(), .waiting)
        XCTAssertEqual(resolve(mode: .off), .paused)
        XCTAssertEqual(ProtectionState.waiting.title, "Boost is OFF")
        XCTAssertEqual(ProtectionState.paused.title, "Boost is OFF")
        XCTAssertNotEqual(ProtectionState.waiting.label, ProtectionState.paused.label)
    }

    func testPendingRestoreIsNotReportedAsFinished() {
        let snapshot = HelperSnapshot(interface: .down, managing: true, leaseCount: 0, error: nil)
        XCTAssertEqual(resolve(mode: .off, snapshot: snapshot), .restoring)
    }
}
