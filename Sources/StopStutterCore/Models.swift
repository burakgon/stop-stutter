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
        WatchedApp(bundleIdentifier: "io.unom.punktfunk", name: "Punktfunk")
    ]

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

    public init(interface: InterfaceState, managing: Bool, leaseCount: Int, error: String?) {
        self.interface = interface
        self.managing = managing
        self.leaseCount = leaseCount
        self.error = error
        self.protocolVersion = ServiceIdentity.protocolVersion
    }

    public var protected: Bool { managing && leaseCount > 0 && interface == .down && error == nil }
}

public enum ServiceIdentity {
    public static let app = "io.github.burakgon.StopStutter"
    public static let helper = "io.github.burakgon.StopStutter.Helper"
    public static let daemonPlist = helper + ".plist"
    public static let protocolVersion = 1
    public static let leaseDuration: TimeInterval = 6
}

@objc public protocol AWDLHelperProtocol {
    /// Each authenticated connection owns one lease. No commands, paths or shell text cross XPC.
    func updateLease(_ suppress: Bool, withReply reply: @escaping (Data) -> Void)
}
