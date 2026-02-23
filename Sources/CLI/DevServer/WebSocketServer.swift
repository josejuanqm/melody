import Foundation
import Network

/// WebSocket server that broadcasts YAML updates to connected clients during development.
final class DevWebSocketServer: @unchecked Sendable {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var latestYaml: String?
    private let queue = DispatchQueue(label: "melody.dev.server")
    let port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func start() throws {
        let parameters = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw DevServerError.invalidPort
        }

        listener = try NWListener(using: parameters, on: nwPort)

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("   WebSocket server listening on ws://localhost:\(self.port)")
            case .failed(let error):
                print("   ✗ Server failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
    }

    /// Broadcast new YAML to all connected clients, with an optional reload reason
    func broadcast(yaml: String, reason: String? = nil) {
        guard let reason else { return }
        latestYaml = yaml
        let payload: String = "---melody-reload: \(reason)\n\(yaml)"
        guard let data = payload.data(using: .utf8) else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "yaml-update",
            metadata: [metadata]
        )

        for connection in connections {
            connection.send(
                content: data,
                contentContext: context,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error = error {
                        print("   ✗ Send error: \(error.localizedDescription)")
                    }
                }
            )
        }
    }

    var connectionCount: Int { connections.count }

    // MARK: - Private

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let count = self?.connections.count ?? 0
                print("   ⬡ Client connected (\(count) active)")
                if let yaml = self?.latestYaml {
                    self?.send(yaml: yaml, to: connection)
                }
            case .cancelled, .failed:
                self?.removeConnection(connection)
                let count = self?.connections.count ?? 0
                print("   ⬡ Client disconnected (\(count) active)")
            default:
                break
            }
        }

        connection.start(queue: queue)
        receiveMessages(from: connection)
    }

    private func receiveMessages(from connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            if error != nil {
                return
            }
            self?.receiveMessages(from: connection)
        }
    }

    private func send(yaml: String, to connection: NWConnection) {
        guard let data = yaml.data(using: .utf8) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "yaml-sync",
            metadata: [metadata]
        )
        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .idempotent
        )
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
    }
}

/// Errors raised when starting or configuring the dev server.
enum DevServerError: Error, LocalizedError {
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .invalidPort: return "Invalid port number"
        }
    }
}
