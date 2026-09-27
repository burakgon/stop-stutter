import Foundation

public enum ProtectionMode: String, Codable, CaseIterable, Identifiable {
    case automatic, on, off
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .automatic: return "Auto"
        case .on: return "Always on"
        case .off: return "Off"
        }
    }

    public func shouldSuppress(matchingApps: Set<String>, sleeping: Bool = false) -> Bool {
        guard !sleeping else { return false }
        switch self {
        case .automatic: return !matchingApps.isEmpty
        case .on: return true
        case .off: return false
        }
    }
}

public struct WatchedApp: Codable, Identifiable, Equatable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public var name: String
    public var path: String?
    public var enabled: Bool

    public init(bundleIdentifier: String, name: String, path: String? = nil, enabled: Bool = true) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
        self.enabled = enabled
    }

    public static let suggestions = [
        WatchedApp(bundleIdentifier: "com.moonlight-stream.Moonlight", name: "Moonlight"),
        WatchedApp(bundleIdentifier: "io.unom.punktfunk", name: "Punktfunk"),
        WatchedApp(bundleIdentifier: "com.nvidia.gfnpc.mall", name: "GeForce NOW"),
        WatchedApp(bundleIdentifier: "tv.parsec.www", name: "Parsec"),
        WatchedApp(bundleIdentifier: "com.valvesoftware.SteamLink17", name: "Steam Link")
    ]

    /// Existing choices, including disabled rules, are never silently re-added or enabled.
    public static func availableSuggestions(in apps: [WatchedApp]) -> [WatchedApp] {
        let selected = Set(apps.map(\.id))
        return suggestions.filter { !selected.contains($0.id) }
    }

    public static func matching(_ apps: [WatchedApp], running: Set<String>) -> Set<String> {
        Set(apps.filter { $0.enabled && running.contains($0.bundleIdentifier) }.map(\.bundleIdentifier))
    }
}

public enum InterfaceState: String, Codable {
    case up, down, unavailable
}

public struct HelperSnapshot: Codable {
    public let interface: InterfaceState
    public let managing: Bool
    public let leaseCount: Int
    public let error: String?
    public let protocolVersion: Int
    /// Times macOS turned AWDL back on during this session and the helper turned it off again.
    /// Optional fields keep both directions of the XPC protocol compatible with 0.1.0 helpers.
    public let revivals: Int?
    public let helperRevision: Int?

    public init(interface: InterfaceState, managing: Bool, leaseCount: Int, error: String?, revivals: Int = 0) {
        self.interface = interface
        self.managing = managing
        self.leaseCount = leaseCount
        self.error = error
        self.protocolVersion = ServiceIdentity.protocolVersion
        self.revivals = revivals
        self.helperRevision = ServiceIdentity.helperRevision
    }

    public var protected: Bool { managing && leaseCount > 0 && interface == .down && error == nil }
}

public enum ServiceIdentity {
    public static let app = "io.github.burakgon.StopStutter"
    public static let helper = "io.github.burakgon.StopStutter.Helper"
    public static let daemonPlist = helper + ".plist"
    public static let protocolVersion = 1
    /// Bumped when helper behavior changes, so the app can tell that an older helper is still running.
    public static let helperRevision = 2
    public static let leaseDuration: TimeInterval = 10
}

@objc public protocol AWDLHelperProtocol {
    /// Each authenticated connection owns one lease. No commands, paths or shell text cross XPC.
    func updateLease(_ suppress: Bool, withReply reply: @escaping (Data) -> Void)
}
