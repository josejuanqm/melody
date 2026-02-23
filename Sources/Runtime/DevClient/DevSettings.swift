#if MELODY_DEV
import Foundation
import Observation

@Observable
/// UserDefaults-backed preferences for the dev server connection and hot-reload toggle.
public final class DevSettings {
    private static let prefix = "melody.dev."

    public var hotReloadEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.prefix + "hotReloadEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.prefix + "hotReloadEnabled") }
    }

    public var devServerHost: String {
        get { UserDefaults.standard.string(forKey: Self.prefix + "devServerHost") ?? "localhost" }
        set { UserDefaults.standard.set(newValue, forKey: Self.prefix + "devServerHost") }
    }

    public var devServerPort: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: Self.prefix + "devServerPort")
            return val != 0 ? val : 8375
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.prefix + "devServerPort") }
    }

    public init() {}
}
#endif
