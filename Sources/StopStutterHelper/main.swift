import Darwin
import Foundation
import os
import StopStutterCore

private let log = Logger(subsystem: ServiceIdentity.helper, category: "Service")

final class HelperService: NSObject, NSXPCListenerDelegate {
    let queue = DispatchQueue(label: ServiceIdentity.helper + ".enforcement", qos: .userInitiated)
    let engine: EnforcementEngine
    private var timer: DispatchSourceTimer?
    private var signals: [DispatchSourceSignal] = []

    init(engine: EnforcementEngine) {
        self.engine = engine
        super.init()
        queue.sync { engine.tick(now: MonotonicTime.now) }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(25))
        timer.setEventHandler { [weak self] in self?.engine.tick(now: MonotonicTime.now) }
        timer.resume()
        self.timer = timer
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: queue)
            source.setEventHandler { [weak self] in
                self?.engine.shutdown(now: MonotonicTime.now)
                exit(0)
            }
            source.resume()
            signals.append(source)
        }
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // The listener has already validated Apple's code signature and our exact app identifier.
        guard connection.effectiveUserIdentifier != 0 else { return false }
        let session = HelperSession(service: self)
        connection.exportedInterface = NSXPCInterface(with: AWDLHelperProtocol.self)
        connection.exportedObject = session
        connection.invalidationHandler = { [weak self] in
            self?.queue.async { self?.engine.disconnect(session.id, now: MonotonicTime.now) }
        }
        connection.interruptionHandler = connection.invalidationHandler
        connection.resume()
        return true
    }
}

final class HelperSession: NSObject, AWDLHelperProtocol {
    let id = UUID()
    private let service: HelperService
    init(service: HelperService) { self.service = service }

    func updateLease(_ suppress: Bool, withReply reply: @escaping (Data) -> Void) {
        service.queue.async { [self] in
            let snapshot = service.engine.updateLease(id, suppress: suppress, now: MonotonicTime.now)
            reply((try? JSONEncoder().encode(snapshot)) ?? Data())
        }
    }
}

do {
    guard geteuid() == 0 else {
        throw ControlError.connectionFailed("The helper must be started by macOS Service Management.")
    }
    let requirement = try PeerTrust.requirement(for: ServiceIdentity.app)
    let engine = try EnforcementEngine(driver: SystemAWDLDriver(), journal: RecoveryJournal())
    let service = HelperService(engine: engine)
    let listener = NSXPCListener(machServiceName: ServiceIdentity.helper)
    listener.setConnectionCodeSigningRequirement(requirement)
    listener.delegate = service
    listener.resume()
    log.info("Helper ready; enforcement interval is one second.")
    withExtendedLifetime((service, listener)) { RunLoop.current.run() }
} catch {
    log.error("Helper could not start: \(error.localizedDescription, privacy: .public)")
    exit(1)
}
