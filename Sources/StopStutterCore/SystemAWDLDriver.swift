import Darwin
import Foundation

/// Reads and changes only awdl0's administrative IFF_UP flag, using the same ioctls as `ifconfig awdl0 up|down`
/// but without spawning a process, so a correction takes microseconds instead of a fork and exec.
public final class SystemAWDLDriver: AWDLDriving {
    public static let interfaceName = "awdl0"

    public init() {}

    public func state() throws -> InterfaceState {
        try withFlags { socket, request in
            guard ioctl(socket, SIOCGIFFLAGS, &request) == 0 else {
                if errno == ENXIO { return .unavailable }
                throw Self.failure()
            }
            return request.ifr_ifru.ifru_flags & Int16(IFF_UP) != 0 ? .up : .down
        }
    }

    public func setUp(_ up: Bool) throws {
        try withFlags { socket, request in
            guard ioctl(socket, SIOCGIFFLAGS, &request) == 0 else {
                throw errno == ENXIO ? ControlError.interfaceMissing : Self.failure()
            }
            if up { request.ifr_ifru.ifru_flags |= Int16(IFF_UP) } else { request.ifr_ifru.ifru_flags &= ~Int16(IFF_UP) }
            guard ioctl(socket, SIOCSIFFLAGS, &request) == 0 else { throw Self.failure() }
        }
    }

    private func withFlags<T>(_ body: (Int32, inout ifreq) throws -> T) throws -> T {
        let socket = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard socket >= 0 else { throw Self.failure() }
        defer { close(socket) }
        var request = ifreq()
        withUnsafeMutableBytes(of: &request.ifr_name) { name in
            name.copyBytes(from: Self.interfaceName.utf8.prefix(name.count - 1))
        }
        return try body(socket, &request)
    }

    private static func failure() -> ControlError {
        ControlError.commandFailed(String(cString: strerror(errno)))
    }
}

/// <sys/sockio.h> defines these with the _IOWR/_IOW function-like macros, which Swift does not import.
let SIOCGIFFLAGS: UInt = 0xC020_6911 // _IOWR('i', 17, struct ifreq)
let SIOCSIFFLAGS: UInt = 0x8020_6910 // _IOW('i', 16, struct ifreq)

public enum MonotonicTime {
    /// Continuous monotonic time includes sleep and is unaffected by wall-clock adjustments.
    public static var now: TimeInterval {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom) / 1_000_000_000
    }
}
