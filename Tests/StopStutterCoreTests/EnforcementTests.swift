import Foundation
import XCTest
@testable import StopStutterCore

final class EnforcementTests: XCTestCase {
    func testWritesOnlyWhenInterfaceIsInTheWrongState() throws {
        // Every write makes the kernel broadcast a flag change to the Wi-Fi daemons, even if nothing changed.
        let (engine, driver, journal) = try fixture()
        let id = UUID()
        let initial = engine.updateLease(id, suppress: true, now: 0)
        XCTAssertTrue(initial.protected)
        XCTAssertTrue(journal.marked)
        engine.tick(now: 1)
        engine.tick(now: 2)
        engine.updateLease(id, suppress: true, now: 3)
        XCTAssertEqual(driver.writes, [false])
    }

    func testMacOSRevivingInterfaceIsCorrectedOnNextEvent() throws {
        let (engine, driver, _) = try fixture()
        _ = engine.updateLease(UUID(), suppress: true, now: 0)
        driver.current = .up
        XCTAssertFalse(engine.snapshot().protected)
        engine.tick(now: 0.1)
        XCTAssertTrue(engine.snapshot().protected)
        XCTAssertEqual(engine.snapshot().revivals, 1)
        XCTAssertEqual(driver.writes, [false, false])
    }

    func testHeartbeatCorrectsRevivalBeforeReplying() throws {
        let (engine, driver, _) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        driver.current = .up
        let reply = engine.updateLease(id, suppress: true, now: 2)
        XCTAssertTrue(reply.protected)
        XCTAssertEqual(reply.revivals, 1)
    }

    func testVerificationRetriesWhenMacOSRevivesDuringTheWrite() throws {
        let (engine, driver, _) = try fixture()
        driver.ignoredWrites = 1
        let state = engine.updateLease(UUID(), suppress: true, now: 0)
        XCTAssertTrue(state.protected)
        XCTAssertNil(state.error)
        XCTAssertEqual(driver.writes, [false, false])
    }

    func testRevivalCountStartsOverWithTheNextSession() throws {
        let (engine, driver, _) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        driver.current = .up
        engine.tick(now: 1)
        XCTAssertEqual(engine.snapshot().revivals, 1)
        engine.updateLease(id, suppress: false, now: 2)
        XCTAssertEqual(engine.snapshot().revivals, 0)
        engine.updateLease(id, suppress: true, now: 3)
        XCTAssertEqual(engine.snapshot().revivals, 0)
    }

    func testIdleOnlyWithoutLeasesOrPendingRestore() throws {
        let (engine, driver, _) = try fixture()
        let id = UUID()
        XCTAssertTrue(engine.isIdle)
        engine.updateLease(id, suppress: true, now: 0)
        XCTAssertFalse(engine.isIdle)
        driver.failUp = true
        engine.updateLease(id, suppress: false, now: 1)
        XCTAssertFalse(engine.isIdle, "A restore is still owed")
        driver.failUp = false
        engine.tick(now: 2)
        XCTAssertTrue(engine.isIdle)
    }

    func testRestoreSkipsTheWriteWhenMacOSAlreadyRevivedAWDL() throws {
        let (engine, driver, journal) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        driver.current = .up
        engine.updateLease(id, suppress: false, now: 0.5)
        XCTAssertEqual(driver.writes, [false])
        XCTAssertFalse(journal.marked)
        XCTAssertFalse(engine.snapshot().managing)
    }

    func testLastClientMustLeaveBeforeRestore() throws {
        let (engine, driver, journal) = try fixture()
        let a = UUID(), b = UUID()
        engine.updateLease(a, suppress: true, now: 0)
        engine.updateLease(b, suppress: true, now: 1)
        engine.updateLease(a, suppress: false, now: 2)
        XCTAssertEqual(engine.expiredLeases, 0, "Released leases are not expiries")
        XCTAssertEqual(driver.current, .down)
        XCTAssertTrue(journal.marked)
        engine.updateLease(b, suppress: false, now: 3)
        XCTAssertEqual(driver.current, .up)
        XCTAssertFalse(journal.marked)
    }

    func testHungClientLosesLeaseAtTenSeconds() throws {
        let (engine, driver, journal) = try fixture()
        engine.updateLease(UUID(), suppress: true, now: 10)
        engine.tick(now: 19.9)
        XCTAssertEqual(driver.current, .down)
        engine.tick(now: 20)
        XCTAssertEqual(driver.current, .up)
        XCTAssertFalse(journal.marked)
        XCTAssertEqual(engine.expiredLeases, 1)
    }

    func testHeartbeatExtendsLease() throws {
        let (engine, driver, _) = try fixture()
        let id = UUID()
        engine.updateLease(id, suppress: true, now: 0)
        engine.updateLease(id, suppress: true, now: 8)
        engine.tick(now: 10)
        XCTAssertEqual(driver.current, .down)
        engine.tick(now: 18)
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
        driver.ignoredWrites = .max
        let state = engine.updateLease(UUID(), suppress: true, now: 0)
        XCTAssertFalse(state.protected)
        XCTAssertNotNil(state.error)
        XCTAssertTrue(journal.marked)
        XCTAssertEqual(driver.writes.count, 3, "Retries are bounded")
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
    /// Writes that "succeed" without changing the interface, like macOS reviving AWDL right after a write.
    var ignoredWrites = 0
    func state() throws -> InterfaceState { current }
    func setUp(_ up: Bool) throws {
        writes.append(up)
        if up && failUp { throw ControlError.restoreFailed }
        if ignoredWrites > 0 { ignoredWrites -= 1 } else { current = up ? .up : .down }
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

final class SystemDriverTests: XCTestCase {
    func testFlagIoctlsMatchTheKernelInterfaceRequest() throws {
        // The hard-coded request numbers encode sizeof(struct ifreq); a mismatch would make the kernel reject them.
        XCTAssertEqual(MemoryLayout<ifreq>.size, 32)
        XCTAssertEqual(Int((SIOCGIFFLAGS >> 16) & 0x1FFF), MemoryLayout<ifreq>.size)
        XCTAssertEqual(Int((SIOCSIFFLAGS >> 16) & 0x1FFF), MemoryLayout<ifreq>.size)
        // Read-only: returns up, down, or unavailable (for Macs and VMs without awdl0) and never changes networking.
        XCTAssertNoThrow(try SystemAWDLDriver().state())
    }
}
