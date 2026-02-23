import Foundation
import Network

/// HTTP server that serves project assets (images, files) during development.
final class StaticFileServer: @unchecked Sendable {
    private let port: UInt16
    private let rootPath: String
    private var listener: NWListener?

    init(port: UInt16, rootPath: String) {
        self.port = port
        self.rootPath = rootPath
    }

    func start() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("   ✗ Asset server failed: \(error)")
            }
        }
        listener.start(queue: .main)
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            self.handleRequest(request, connection: connection)
        }
    }

    private func handleRequest(_ request: String, connection: NWConnection) {
        guard let firstLine = request.components(separatedBy: "\r\n").first else {
            sendResponse(connection: connection, status: "400 Bad Request", body: Data())
            return
        }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            sendResponse(connection: connection, status: "400 Bad Request", body: Data())
            return
        }

        let rawPath = parts[1]
        let decoded = rawPath.removingPercentEncoding ?? rawPath
        let relativePath = decoded.hasPrefix("/") ? String(decoded.dropFirst()) : decoded

        guard !relativePath.contains("..") else {
            sendResponse(connection: connection, status: "403 Forbidden", body: Data())
            return
        }

        let filePath = (rootPath as NSString).appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: filePath),
              let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            sendResponse(connection: connection, status: "404 Not Found", body: Data())
            return
        }

        let contentType = mimeType(for: (filePath as NSString).pathExtension)
        sendResponse(connection: connection, status: "200 OK", contentType: contentType, body: fileData)
    }

    private func sendResponse(connection: NWConnection, status: String, contentType: String = "text/plain", body: Data) {
        var header = "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        var responseData = header.data(using: .utf8)!
        responseData.append(body)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}
