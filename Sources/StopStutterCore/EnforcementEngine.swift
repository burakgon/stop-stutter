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

/// All methods must run on one serial queue. The timer lives in the privileged helper.
/// A durable marker is written BEFORE changing AWDL, and cleared only after verified recovery.
public final class EnforcementEngine {
    private let driver: AWDLDriving
    private let journal: RecoveryJournaling
    private var leases: [UUID: TimeInterval] = [:]
    private var managing: Bool
    private var lastError: String?

    public init(driver: AWDLDriving, journal: RecoveryJournaling) throws {
        self.driver = driver
        self.journal = journal
        self.managing = try journal.needsRestore
    }

    @discardableResult
    public func updateLease(_ id: UUID, suppress: Bool, now: TimeInterval) -> HelperSnapshot {
        let wasActive = !leases.isEmpty
        if suppress {
            leases[id] = now + ServiceIdentity.leaseDuration
        } else {
            leases.removeValue(forKey: id)
        }
        // Enforce immediately on entry; the dedicated timer handles subsequent one-second writes.
        if !suppress || !wasActive { reconcile(now: now) }
        return snapshot()
    }

    public func disconnect(_ id: UUID, now: TimeInterval) {
        leases.removeValue(forKey: id)
        reconcile(now: now)
    }

    public func tick(now: TimeInterval) { reconcile(now: now) }

    public func shutdown(now: TimeInterval) {
        leases.removeAll()
        reconcile(now: now)
    }

    public func snapshot() -> HelperSnapshot {
        do {
            return HelperSnapshot(interface: try driver.state(), managing: managing,
                                  leaseCount: leases.count, error: lastError)
        } catch {
            return HelperSnapshot(interface: .unavailable, managing: managing,
                                  leaseCount: leases.count, error: error.localizedDescription)
        }
    }

    private func reconcile(now: TimeInterval) {
        leases = leases.filter { $0.value > now }
        do {
            if !leases.isEmpty {
                guard try driver.state() != .unavailable else { throw ControlError.interfaceMissing }
                if !managing {
                    try journal.markForRestore()
                    managing = true
                }
                // Intentionally unconditional: macOS can revive AWDL between ticks.
                try driver.setUp(false)
                guard try driver.state() == .down else { throw ControlError.verificationFailed }
            } else if managing {
                try driver.setUp(true)
                guard try driver.state() == .up else { throw ControlError.restoreFailed }
                try journal.clear()
                managing = false
            }
            lastError = nil
        } catch {
            // Keep recovery ownership/marker on failure and retry on the next tick.
            lastError = error.localizedDescription
        }
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
