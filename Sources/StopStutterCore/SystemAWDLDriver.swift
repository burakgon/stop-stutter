import Darwin
import Foundation

public final class SystemAWDLDriver: AWDLDriving {
    public init() {}

    public func state() throws -> InterfaceState {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0 else {
            throw ControlError.commandFailed(String(cString: strerror(errno)))
        }
        defer { freeifaddrs(addresses) }
        var cursor = addresses
        while let address = cursor {
            defer { cursor = address.pointee.ifa_next }
            if String(cString: address.pointee.ifa_name) == "awdl0" {
                return address.pointee.ifa_flags & UInt32(IFF_UP) != 0 ? .up : .down
            }
        }
        return .unavailable
    }

    public func setUp(_ up: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = ["awdl0", up ? "up" : "down"]
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL": "C"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        let deadline = MonotonicTime.now + 0.75
        while process.isRunning && MonotonicTime.now < deadline { usleep(5_000) }
        if process.isRunning {
            // Bounded execution prevents a stuck child from blocking lease expiry or recovery.
            kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
            throw ControlError.commandFailed("ifconfig timed out.")
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            throw ControlError.commandFailed(String(message.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

public enum MonotonicTime {
    /// Continuous monotonic time includes sleep and is unaffected by wall-clock adjustments.
    public static var now: TimeInterval {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom) / 1_000_000_000
    }
}
