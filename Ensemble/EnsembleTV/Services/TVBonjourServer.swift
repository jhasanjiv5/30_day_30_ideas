import EnsembleCore
import Foundation
import Network

@MainActor
final class TVBonjourServer {
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var participantConnections: [UUID: ObjectIdentifier] = [:]
    private var buffers: [ObjectIdentifier: Data] = [:]

    var onMessage: ((WireMessage, UUID?) -> Void)?

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let listener = try NWListener(using: params)
            listener.service = NWListener.Service(
                name: "Living Room Apple TV",
                type: WireMessage.bonjourServiceType
            )

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            // Listener failed to bind; keep UI responsive without crashing
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for conn in connections.values {
            conn.cancel()
        }
        connections.removeAll()
        participantConnections.removeAll()
        buffers.removeAll()
    }

    func send(_ message: WireMessage, to participantID: UUID) {
        guard let connID = participantConnections[participantID],
              let conn = connections[connID],
              let data = try? LengthPrefixedFraming.encode(message) else {
            return
        }
        conn.send(content: data, completion: .contentProcessed { _ in })
    }

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        buffers[key] = Data()

        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                Task { @MainActor in
                    self?.removeConnection(key)
                }
            } else if case .cancelled = state {
                Task { @MainActor in
                    self?.removeConnection(key)
                }
            }
        }

        connection.start(queue: .main)
        receiveLoop(connection: connection, key: key)
    }

    private func receiveLoop(connection: NWConnection, key: ObjectIdentifier) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data, !data.isEmpty {
                    var buf = self.buffers[key] ?? Data()
                    buf.append(data)
                    if let messages = try? LengthPrefixedFraming.decodeMessages(from: &buf) {
                        for message in messages {
                            self.associateParticipantIfNeeded(message: message, key: key)
                            self.onMessage?(message, self.participantID(for: message))
                        }
                    }
                    self.buffers[key] = buf
                }

                if isComplete || error != nil {
                    self.removeConnection(key)
                } else {
                    self.receiveLoop(connection: connection, key: key)
                }
            }
        }
    }

    private func associateParticipantIfNeeded(message: WireMessage, key: ObjectIdentifier) {
        if let pid = participantID(for: message) {
            participantConnections[pid] = key
        }
    }

    private func participantID(for message: WireMessage) -> UUID? {
        switch message {
        case .join(let payload): return payload.participantID
        case .leave(let payload): return payload.participantID
        case .heartbeat(let payload): return payload.participantID
        case .tasteVector(let id, _): return id
        case .query(let payload): return payload.participantID
        case .recap(let payload): return payload.participantID
        case .command(let payload): return payload.participantID
        case .subtitleWindow: return nil
        }
    }

    private func removeConnection(_ key: ObjectIdentifier) {
        connections.removeValue(forKey: key)
        buffers.removeValue(forKey: key)
        for (pid, connKey) in participantConnections where connKey == key {
            participantConnections.removeValue(forKey: pid)
        }
    }
}
