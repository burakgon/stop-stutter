import Foundation

public protocol AWDLDriving: AnyObject {
    func state() throws -> InterfaceState
    func setUp(_ up: Bool) throws
}

public protocol RecoveryJournaling: AnyObject {
    var needsRestore: Bool { get throws }
    func markForRestore() throws
    func clear() throws
}

/// All methods must run on one serial queue. Interface events and the safety timer live in the privileged helper.
/// A durable marker is written BEFORE changing AWDL, and cleared only after verified recovery.
public final class EnforcementEngine {
    private let driver: AWDLDriving
    private let journal: RecoveryJournaling
    private var leases: [UUID: TimeInterval] = [:]
    private var managing: Bool
    public private(set) var lastError: String?
    /// Times macOS turned AWDL back on while the helper held it down. Resets when control ends.
    public private(set) var revivals = 0
    /// Leases that ran out without renewal: an app stopped sending heartbeats while it wanted Boost.
    public private(set) var expiredLeases = 0

    public init(driver: AWDLDriving, journal: RecoveryJournaling) throws {
        self.driver = driver
        self.journal = journal
        self.managing = try journal.needsRestore
    }

    /// No lease and no restore owed, so the helper can exit without leaving AWDL down.
    public var isIdle: Bool { leases.isEmpty && !managing }

    @discardableResult
    public func updateLease(_ id: UUID, suppress: Bool, now: TimeInterval) -> HelperSnapshot {
        if suppress {
            leases[id] = now + ServiceIdentity.leaseDuration
        } else {
            leases.removeValue(forKey: id)
        }
        // Heartbeats enforce too, so a reply never reports a revival the helper has not corrected yet.
        reconcile(now: now)
        return snapshot()
    }

    public func disconnect(_ id: UUID, now: TimeInterval) {
        leases.removeValue(forKey: id)
        reconcile(now: now)
    }

    /// Runs on every interface event and every safety tick.
    public func tick(now: TimeInterval) { reconcile(now: now) }

    public func shutdown(now: TimeInterval) {
        leases.removeAll()
        reconcile(now: now)
    }

    public func snapshot() -> HelperSnapshot {
        do {
            return HelperSnapshot(interface: try driver.state(), managing: managing,
                                  leaseCount: leases.count, error: lastError, revivals: revivals)
        } catch {
            return HelperSnapshot(interface: .unavailable, managing: managing,
                                  leaseCount: leases.count, error: error.localizedDescription, revivals: revivals)
        }
    }

    private func reconcile(now: TimeInterval) {
        let live = leases.filter { $0.value > now }
        expiredLeases += leases.count - live.count
        leases = live
        do {
            let current = try driver.state()
            if !leases.isEmpty {
                guard current != .unavailable else { throw ControlError.interfaceMissing }
                if !managing {
                    try journal.markForRestore()
                    managing = true
                } else if current == .up {
                    revivals += 1
                }
                if current == .up { try holdDown() }
            } else if managing {
                if current != .up {
                    try driver.setUp(true)
                    guard try driver.state() == .up else { throw ControlError.restoreFailed }
                }
                try journal.clear()
                managing = false
                revivals = 0
            }
            lastError = nil
        } catch {
            // Keep recovery ownership/marker on failure and retry on the next event or tick.
            lastError = error.localizedDescription
        }
    }

    /// Writes only when AWDL is actually up: every write makes the kernel broadcast a flag change to the
    /// Wi-Fi daemons, even when nothing changed. Extra attempts cover macOS reviving AWDL mid-verification.
    private func holdDown() throws {
        for _ in 0..<3 {
            try driver.setUp(false)
            if try driver.state() == .down { return }
        }
        throw ControlError.verificationFailed
    }
}

public enum ControlError: LocalizedError {
    case interfaceMissing, verificationFailed, restoreFailed, unsignedBuild
    case commandFailed(String), invalidJournal, connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .interfaceMissing: return "This Mac does not currently expose an awdl0 interface."
        case .verificationFailed: return "macOS re-enabled AWDL before verification. Retrying automatically."
        case .restoreFailed: return "AWDL could not be restored yet. The helper will keep retrying."
        case .unsignedBuild: return "The helper requires a build signed with an Apple Development or Developer ID certificate."
        case .commandFailed(let message): return "AWDL command failed: \(message)"
        case .invalidJournal: return "The helper recovery directory has unsafe ownership or permissions."
        case .connectionFailed(let message): return message
        }
    }
}
