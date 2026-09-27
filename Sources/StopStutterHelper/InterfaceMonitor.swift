import Darwin
import Foundation
import StopStutterCore

/// The kernel reports every interface's IFF_UP transition on a routing socket (RTM_IFINFO), so a macOS revival of
/// AWDL is corrected within milliseconds instead of on the next safety tick. Callbacks run on `queue`, bursts are
/// coalesced, and calls are spaced at least `minimumInterval` apart so a daemon fighting back cannot cause a busy loop.
final class InterfaceMonitor {
    private let queue: DispatchQueue
    private let minimumInterval: TimeInterval
    private let handler: () -> Void
    private let socket: Int32
    private let source: DispatchSourceRead
    private var lastRun = -TimeInterval.infinity
    private var scheduled = false

    init(queue: DispatchQueue, minimumInterval: TimeInterval = 0.02, handler: @escaping () -> Void) throws {
        let socket = Darwin.socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)
        guard socket >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard fcntl(socket, F_SETFL, fcntl(socket, F_GETFL) | O_NONBLOCK) == 0 else {
            let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            close(socket)
            throw error
        }
        self.queue = queue
        self.minimumInterval = minimumInterval
        self.handler = handler
        self.socket = socket
        source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: queue)
        source.setEventHandler { [weak self] in self?.drain() }
        source.setCancelHandler { close(socket) }
        source.resume()
    }

    deinit { source.cancel() }

    private func drain() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var interfaceChanged = false
        while true {
            let count = read(socket, &buffer, buffer.count)
            if count < 0 {
                if errno == EINTR { continue }
                if errno == ENOBUFS { interfaceChanged = true; continue } // Messages were dropped; check anyway.
                break
            }
            if count == 0 { break }
            // Every routing message starts with its length (2 bytes), version (1) and type (1).
            if count > 3 && Int32(buffer[3]) == RTM_IFINFO { interfaceChanged = true }
        }
        if interfaceChanged { schedule() }
    }

    private func schedule() {
        guard !scheduled else { return }
        let delay = lastRun + minimumInterval - MonotonicTime.now
        guard delay > 0 else { return run() }
        scheduled = true
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.scheduled = false
            self?.run()
        }
    }

    private func run() {
        lastRun = MonotonicTime.now
        handler()
    }
}
