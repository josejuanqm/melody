#if MELODY_DEV
import Foundation
import Observation
import Core

@MainActor
@Observable
/// WebSocket client that receives YAML updates from the dev server and triggers live reloads.
public final class HotReloadClient {
    public private(set) var latestApp: AppDefinition?
    public private(set) var isConnected = false
    public private(set) var reloadCount = 0

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let parser = AppParser()
    private var shouldReconnect = true

    public init() {}

    /// Connect to the dev server
    public func connect(host: String = "localhost", port: Int = 8375) {
        shouldReconnect = true
        let url = URL(string: "ws://\(host):\(port)")!
        session = URLSession(configuration: .default)
        startConnection(url: url)
    }

    /// Disconnect from the dev server
    public func disconnect() {
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - Private

    private func startConnection(url: URL) {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        let task = session!.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        isConnected = true
        DevLogger.shared.log("Connected to \(url)", source: "hotreload")
        receiveMessage(url: url)
    }

    private func receiveMessage(url: URL) {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let yaml):
                        self.handleYamlUpdate(yaml)
                    case .data(let data):
                        if let yaml = String(data: data, encoding: .utf8) {
                            self.handleYamlUpdate(yaml)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage(url: url)

                case .failure(let error):
                    self.isConnected = false
                    DevLogger.shared.log("Connection failed: \(error.localizedDescription)", source: "hotreload")
                    if self.shouldReconnect {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        guard self.shouldReconnect else { return }
                        self.startConnection(url: url)
                    }
                }
            }
        }
    }

    private func handleYamlUpdate(_ rawPayload: String) {
        var yaml = rawPayload
        var reason: String?

        // Parse optional reload reason header: "---melody-reload: <reason>\n"
        let prefix = "---melody-reload: "
        if yaml.hasPrefix(prefix), let newline = yaml.firstIndex(of: "\n") {
            reason = String(yaml[yaml.index(yaml.startIndex, offsetBy: prefix.count)..<newline])
            yaml = String(yaml[yaml.index(after: newline)...])
        }

        do {
            let app = try parser.parse(yaml)
            Task { @MainActor in
                self.latestApp = app
                self.reloadCount += 1
                let detail = reason.map { " — \($0)" } ?? ""
                DevLogger.shared.log("Reload #\(self.reloadCount)\(detail)", source: "hotreload")
            }
        } catch {
            DevLogger.shared.log("Parse error: \(error.localizedDescription)", source: "hotreload")
        }
    }
}
#endif
