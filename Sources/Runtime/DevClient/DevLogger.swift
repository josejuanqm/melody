#if MELODY_DEV
import Foundation
import Observation

@Observable
/// Capped in-memory log buffer surfaced in ``DevSettingsView`` during development.
public final class DevLogger: @unchecked Sendable {
    public static let shared = DevLogger()

    public struct LogEntry: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let message: String
        public let source: String
    }

    public private(set) var entries: [LogEntry] = []
    private let maxEntries = 500

    private init() {}

    public func log(_ message: String, source: String = "system") {
        let entry = LogEntry(timestamp: Date(), message: message, source: source)
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
        #if MELODY_DEV
        print(source, message)
        #endif
    }

    public func clear() {
        entries.removeAll()
    }
}
#endif
