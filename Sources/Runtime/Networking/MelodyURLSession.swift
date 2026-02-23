import Foundation

/// Shared URLSession singleton with per-host SSL trust management.
public final class MelodyURLSession: NSObject, URLSessionDelegate, @unchecked Sendable {
    public static let shared = MelodyURLSession()

    private let trustedHostsKey = "melody_trusted_hosts"
    private let lock = NSLock()
    private var _trustedHosts: Set<String>
    public private(set) lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        let saved = UserDefaults.standard.stringArray(forKey: trustedHostsKey) ?? []
        _trustedHosts = Set(saved)
        super.init()
    }

    /// Add a host to the trusted list and persist it
    public func trustHost(_ host: String) {
        _ = lock.withLock { _trustedHosts.insert(host) }
        UserDefaults.standard.set(Array(lock.withLock { _trustedHosts }), forKey: trustedHostsKey)
    }

    /// Check if a host is trusted
    public func isHostTrusted(_ host: String) -> Bool {
        lock.withLock { _trustedHosts.contains(host) }
    }

    // MARK: - URLSessionDelegate

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let isTrusted = lock.withLock { _trustedHosts.contains(challenge.protectionSpace.host) }
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust,
           isTrusted {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    /// Check if an error is an SSL certificate error
    public static func isSSLError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return nsError.code == NSURLErrorServerCertificateUntrusted
            || nsError.code == NSURLErrorServerCertificateHasBadDate
            || nsError.code == NSURLErrorServerCertificateHasUnknownRoot
            || nsError.code == NSURLErrorServerCertificateNotYetValid
    }
}
