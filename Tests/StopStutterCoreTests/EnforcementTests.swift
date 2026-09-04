import Foundation
import XCTest
@testable import StopStutterCore

final class EnforcementTests: XCTestCase {
    func testKeepsWritingDownEveryTickEvenWhenAlreadyDown() throws {
        let (engine, driver, journal) = try fixture()
        let id = UUID()
        let initial = engine.updateLease(id, suppress: true, now: 0)
        XCTAssertTrue(initial.protected)
        XCTAssertTrue(journal.marked)
        engine.tick(now: 1)
        engine.tick(now: 2)
        XCTAssertEqual(driver.writes, [false, false, false])
    }

    func testMacOSRevivingInterfaceIsCorrectedOnNextTick() throws {
        let (engine, driver, _) = try fixture()
        _ = engine.updateLease(UUID(), suppress: true, now: 0)
        driver.current = .up
        XCTAssertFalse(engine.snapshot().protected)
        engine.tick(now: 1)
        XCTAssertTrue(engine.snapshot().protected)
    }

    func testLastClientMustLeaveBeforeRestore() throws {
        let (engine, driver, journal) = try fixture()
        let a = UUID(), b = UUID()
        engine.updateLease(a, suppress: true, now: 0)
        engine.updateLease(b, suppress: true, now: 1)
        engine.updateLease(a, suppress: false, now: 2)
        XCTAssertEqual(driver.current, .down)
        XCTAssertTrue(journal.marked)
        engine.updateLease(b, suppress: false, now: 3)
        XCTAssertEqual(driver.current, .up)
        XCTAssertFalse(journal.marked)
    }

    func testHungClientLosesLeaseAtSixSeconds() throws {
        let (engine, driver, journal) = try fixture()
        engine.updateLease(UUID(), suppress: true, now: 10)
        engine.tick(now: 15.9)
        XCTAssertEqual(driver.current, .down)
        engine.tick(now: 16)
        XCTAssertEqual(driver.current, .up)
        XCTAssertFalse(journal.marked)
    }

    func testHeartbeatExtendsLease() throws {
        let (engine, driver, _) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        engine.updateLease(id, suppress: true, now: 4)
        engine.tick(now: 6)
        XCTAssertEqual(driver.current, .down)
        engine.tick(now: 10)
        XCTAssertEqual(driver.current, .up)
    }

    func testDisconnectedClientRestoresImmediately() throws {
        let (engine, driver, _) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        engine.disconnect(id, now: 0.5)
        XCTAssertEqual(driver.current, .up)
    }

    func testHelperRestartRecoversDurableMarkerBeforeAcceptingWork() throws {
        let driver = FakeDriver(), journal = FakeJournal()
        journal.marked = true
        driver.current = .down
        let engine = try EnforcementEngine(driver: driver, journal: journal)
        engine.tick(now: 100)
        XCTAssertEqual(driver.writes, [true])
        XCTAssertFalse(journal.marked)
    }

    func testIdleDaemonNeverChangesInterfaceWithoutOwnership() throws {
        let (engine, driver, _) = try fixture()
        driver.current = .down
        engine.tick(now: 1)
        engine.updateLease(UUID(), suppress: false, now: 2)
        XCTAssertTrue(driver.writes.isEmpty)
        XCTAssertEqual(driver.current, .down)
    }

    func testFailedJournalWritePreventsAnyNetworkMutation() throws {
        let (engine, driver, journal) = try fixture()
        journal.failMark = true
        let state = engine.updateLease(UUID(), suppress: true, now: 0)
        XCTAssertNotNil(state.error)
        XCTAssertFalse(state.protected)
        XCTAssertTrue(driver.writes.isEmpty)
    }

    func testFailedRestoreRetainsMarkerAndRetries() throws {
        let (engine, driver, journal) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        driver.failUp = true
        let failed = engine.updateLease(id, suppress: false, now: 1)
        XCTAssertNotNil(failed.error)
        XCTAssertTrue(journal.marked)
        driver.failUp = false
        engine.tick(now: 2)
        XCTAssertEqual(driver.current, .up)
        XCTAssertFalse(journal.marked)
        XCTAssertNil(engine.snapshot().error)
    }

    func testSilentFailureCannotClaimProtection() throws {
        let (engine, driver, journal) = try fixture()
        driver.ignoreWrites = true
        let state = engine.updateLease(UUID(), suppress: true, now: 0)
        XCTAssertFalse(state.protected)
        XCTAssertNotNil(state.error)
        XCTAssertTrue(journal.marked)
    }

    func testFailedJournalClearRetainsRecoveryOwnership() throws {
        let (engine, _, journal) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        journal.failClear = true
        let state = engine.updateLease(id, suppress: false, now: 1)
        XCTAssertTrue(state.managing)
        XCTAssertNotNil(state.error)
        journal.failClear = false
        engine.tick(now: 2)
        XCTAssertFalse(engine.snapshot().managing)
    }

    func testMissingInterfaceFailsWithoutClaimingOwnership() throws {
        let (engine, driver, journal) = try fixture()
        driver.current = .unavailable
        let state = engine.updateLease(UUID(), suppress: true, now: 0)
        XCTAssertFalse(state.protected)
        XCTAssertNotNil(state.error)
        XCTAssertFalse(journal.marked)
        XCTAssertTrue(driver.writes.isEmpty)
    }

    func testShutdownRestoresAndDropsAllLeases() throws {
        let (engine, driver, journal) = try fixture()
        engine.updateLease(UUID(), suppress: true, now: 0)
        engine.updateLease(UUID(), suppress: true, now: 0)
        engine.shutdown(now: 1)
        XCTAssertEqual(driver.current, .up)
        XCTAssertEqual(engine.snapshot().leaseCount, 0)
        XCTAssertFalse(journal.marked)
    }

    func testSleepLengthJumpExpiresLeases() throws {
        let (engine, driver, _) = try fixture()
        engine.updateLease(UUID(), suppress: true, now: 0)
        engine.tick(now: 3600)
        XCTAssertEqual(driver.current, .up)
    }

    private func fixture() throws -> (EnforcementEngine, FakeDriver, FakeJournal) {
        let driver = FakeDriver(), journal = FakeJournal()
        return (try EnforcementEngine(driver: driver, journal: journal), driver, journal)
    }
}

private final class FakeDriver: AWDLDriving {
    var current = InterfaceState.up
    var writes: [Bool] = []
    var failUp = false
    var ignoreWrites = false
    func state() throws -> InterfaceState { current }
    func setUp(_ up: Bool) throws {
        writes.append(up)
        if up && failUp { throw ControlError.restoreFailed }
        if !ignoreWrites { current = up ? .up : .down }
    }
}

private final class FakeJournal: RecoveryJournaling {
    var marked = false
    var failMark = false
    var failClear = false
    var needsRestore: Bool { marked }
    func markForRestore() throws {
        if failMark { throw ControlError.invalidJournal }
        marked = true
    }
    func clear() throws {
        if failClear { throw ControlError.invalidJournal }
        marked = false
    }
}
