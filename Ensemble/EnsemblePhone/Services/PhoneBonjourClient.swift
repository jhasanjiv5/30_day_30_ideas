import EnsembleCore
import Foundation
import Network

@MainActor
final class PhoneBonjourClient {
    enum ConnectionState: Equatable {
        case searching
        case connected(String)
        case disconnected
    }

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var heartbeatTask: Task<Void, Never>?

    var onStateChange: ((ConnectionState) -> Void)?
    var onMessage: ((WireMessage) -> Void)?

    func startBrowsing() {
        guard browser == nil else { return }
        onStateChange?(.searching)

        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: WireMessage.bonjourServiceType, domain: nil), using: params)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self, self.connection == nil, let first = results.first else { return }
                self.connect(to: first.endpoint)
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stopAll() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        connection?.cancel()
        connection = nil
        browser?.cancel()
        browser = nil
        receiveBuffer.removeAll()
        onStateChange?(.disconnected)
    }

    func send(_ message: WireMessage) {
        guard let connection,
              let data = try? LengthPrefixedFraming.encode(message) else {
            return
        }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func startHeartbeat(participantID: UUID) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(WireMessage.heartbeatIntervalSeconds))
                guard !Task.isCancelled, let self else { break }
                self.send(.heartbeat(HeartbeatPayload(participantID: participantID, sentAt: .now)))
            }
        }
    }

    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func connect(to endpoint: NWEndpoint) {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.onStateChange?(.connected("Living Room Apple TV"))
                case .failed, .cancelled:
                    self.connection = nil
                    self.stopHeartbeat()
                    self.onStateChange?(.searching)
                default:
                    break
                }
            }
        }

        conn.start(queue: .main)
        receiveLoop(conn)
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.receiveBuffer.append(data)
                    if let messages = try? LengthPrefixedFraming.decodeMessages(from: &self.receiveBuffer) {
                        for message in messages {
                            self.onMessage?(message)
                        }
                    }
                }
                if isComplete || error != nil {
                    self.connection = nil
                    self.stopHeartbeat()
                    self.onStateChange?(.searching)
                } else {
                    self.receiveLoop(conn)
                }
            }
        }
    }
}
