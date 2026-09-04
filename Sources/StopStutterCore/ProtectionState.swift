import Foundation

/// User-facing state follows verified helper feedback, never just the selected mode.
public enum ProtectionState: Equatable {
    case active, waiting, paused, setup, starting, restoring, checking, attention

    public static func resolve(ready: Bool, connected: Bool, requested: Bool,
                               mode: ProtectionMode, snapshot: HelperSnapshot?, hasError: Bool) -> Self {
        if hasError { return .attention }
        if connected, snapshot?.protected == true { return .active }
        if !ready { return .setup }
        if !connected { return .checking }
        if snapshot?.managing == true && snapshot?.leaseCount == 0 { return .restoring }
        if requested { return .starting }
        return mode == .off ? .paused : .waiting
    }

    public var title: String {
        switch self {
        case .active: return "Protection is ON"
        case .waiting, .paused, .setup: return "Protection is OFF"
        case .starting: return "Turning protection on…"
        case .restoring: return "Restoring AWDL…"
        case .checking: return "Checking protection…"
        case .attention: return "Protection needs attention"
        }
    }

    public var label: String {
        switch self {
        case .active: return "ACTIVE · AWDL HELD OFF"
        case .waiting: return "AUTO · WAITING FOR AN APP"
        case .paused: return "PAUSED · AUTOMATION OFF"
        case .setup: return "SETUP REQUIRED"
        case .starting: return "STARTING · PLEASE WAIT"
        case .restoring: return "RESTORING APPLE SHARING"
        case .checking: return "CONNECTING TO HELPER"
        case .attention: return "ACTION NEEDED"
        }
    }
}
