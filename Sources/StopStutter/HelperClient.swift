import Foundation
import StopStutterCore

@MainActor
final class HelperClient {
    private var connection: NSXPCConnection?

    func update(suppress: Bool) async throws -> HelperSnapshot {
        let connection = try connect()
        return try await withCheckedThrowingContinuation { continuation in
            let reply = ReplyOnce(continuation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                reply.finish(.failure(ControlError.connectionFailed("The helper did not respond. Check its approval in System Settings.")))
            }
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                reply.finish(.failure(error))
            }) as? AWDLHelperProtocol else {
                reply.finish(.failure(ControlError.connectionFailed("Could not connect to the AWDL helper.")))
                return
            }
            proxy.updateLease(suppress) { data in
                do {
                    let snapshot = try JSONDecoder().decode(HelperSnapshot.self, from: data)
                    guard snapshot.protocolVersion == ServiceIdentity.protocolVersion else {
                        throw ControlError.connectionFailed("The helper needs updating. Remove and enable it again in Settings.")
                    }
                    reply.finish(.success(snapshot))
                } catch { reply.finish(.failure(error)) }
            }
        }
    }

    func invalidate() {
        connection?.invalidate()
        connection = nil
    }

    private func connect() throws -> NSXPCConnection {
        if let connection { return connection }
        let requirement = try PeerTrust.requirement(for: ServiceIdentity.helper)
        let connection = NSXPCConnection(machServiceName: ServiceIdentity.helper, options: .privileged)
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: AWDLHelperProtocol.self)
        connection.resume()
        self.connection = connection
        return connection
    }
}

/// XPC can race a timeout, invalidation and reply. Resume the continuation exactly once.
private final class ReplyOnce {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<HelperSnapshot, Error>?

    init(_ continuation: CheckedContinuation<HelperSnapshot, Error>) { self.continuation = continuation }

    func finish(_ result: Result<HelperSnapshot, Error>) {
        lock.lock()
        let current = continuation
        continuation = nil
        lock.unlock()
        current?.resume(with: result)
    }
}
