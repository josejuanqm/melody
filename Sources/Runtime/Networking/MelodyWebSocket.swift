import Foundation

/// Callback-driven WebSocket client used by Lua scripts for real-time communication.
final class MelodyWebSocket: NSObject, @unchecked Sendable, URLSessionWebSocketDelegate {
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?

    var onOpen: (() -> Void)?
    var onMessage: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onClose: ((Int, String?) -> Void)?

    /// Connect to a WebSocket URL with optional headers.
    func connect(url: URL, headers: [String: String]?) {
        session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil
        )

        var request = URLRequest(url: url)
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        task = session!.webSocketTask(with: request)
        task?.resume()
        listen()
    }

    /// Send a text message.
    func send(_ text: String) {
        task?.send(.string(text)) { error in
            if let error = error {
                DispatchQueue.main.async { [weak self] in
                    self?.onError?(error.localizedDescription)
                }
            }
        }
    }

    /// Close the connection with a code and optional reason.
    func close(code: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: String? = nil) {
        let reasonData = reason?.data(using: .utf8)
        task?.cancel(with: code, reason: reasonData)
    }

    /// Force-close and release all callbacks.
    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        onOpen = nil
        onMessage = nil
        onError = nil
        onClose = nil
    }

    // MARK: - Private

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    switch message {
                    case .string(let text):
                        self.onMessage?(text)
                    case .data(let data):
                        let text = String(data: data, encoding: .utf8) ?? ""
                        self.onMessage?(text)
                    @unknown default:
                        break
                    }
                }
                self.listen()
            case .failure(let error):
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.onOpen?()
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) }
        DispatchQueue.main.async { [weak self] in
            self?.onClose?(closeCode.rawValue, reasonString)
        }
    }

    // MARK: - URLSessionDelegate (SSL Trust)

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust,
           MelodyURLSession.shared.isHostTrusted(challenge.protectionSpace.host) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
