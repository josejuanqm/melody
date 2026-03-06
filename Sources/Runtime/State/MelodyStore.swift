import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Environment Key

private struct MelodyStoreKey: EnvironmentKey {
    static let defaultValue = MelodyStore()
}

extension EnvironmentValues {
    public var melodyStore: MelodyStore {
        get { self[MelodyStoreKey.self] }
        set { self[MelodyStoreKey.self] = newValue }
    }
}

/// Key-value store shared across screens
/// - `set` / `get` for ephemeral (in-memory) values
/// - `save` for persistent values (UserDefaults)
/// - `get` checks memory first, then disk
public final class MelodyStore: @unchecked Sendable {
    private var cache: [String: LuaValue] = [:]
    private let defaults: UserDefaults
    private let prefix: String

    public init(suiteName: String? = nil) {
        if let suiteName {
            self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            self.defaults = .standard
        }
        prefix = "melody.store.\(Bundle.main.bundleIdentifier ?? "")-"
    }

    /// In-memory only — lost on app restart
    public func set(key: String, value: LuaValue) {
        cache[prefix + key] = value
    }

    /// Persists to UserDefaults and memory
    public func save(key: String, value: LuaValue) {
        cache[prefix + key] = value
        let wrapped: [String: Any] = ["v": MelodyHTTP.luaValueToJSON(value)]
        if let data = try? JSONSerialization.data(withJSONObject: wrapped) {
            defaults.set(data, forKey: prefix + key)
        }
        #if canImport(WidgetKit)
        WidgetKit.WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Reads from memory first, falls back to UserDefaults
    public func get(key: String) -> LuaValue {
        if let cached = cache[prefix + key] {
            return cached
        }
        if let data = defaults.data(forKey: prefix + key),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let inner = json["v"],
           let value = MelodyHTTP.jsonToLuaValue(inner) {
            cache[prefix + key] = value
            return value
        }
        return .nil
    }

    /// Saves theme colors to shared UserDefaults for widget access
    public func saveThemeColors(_ colors: [String: String]) {
        if let data = try? JSONSerialization.data(withJSONObject: colors) {
            defaults.set(data, forKey: "melody.theme.colors")
        }
    }

}
