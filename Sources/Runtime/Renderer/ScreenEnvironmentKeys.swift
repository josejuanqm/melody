import SwiftUI

// MARK: - Theme Colors Environment Key

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: [String: String] = [:]
}

extension EnvironmentValues {
    var themeColors: [String: String] {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

// MARK: - App Lua Prelude Environment Key

private struct AppLuaPreludeKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var appLuaPrelude: String? {
        get { self[AppLuaPreludeKey.self] }
        set { self[AppLuaPreludeKey.self] = newValue }
    }
}

// MARK: - Dev Mode Environment Key

private struct DevModeConnectedKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    public var devModeConnected: Bool? {
        get { self[DevModeConnectedKey.self] }
        set { self[DevModeConnectedKey.self] = newValue }
    }
}

// MARK: - Asset Base URL Environment Key

private struct AssetBaseURLKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var assetBaseURL: String? {
        get { self[AssetBaseURLKey.self] }
        set { self[AssetBaseURLKey.self] = newValue }
    }
}

// MARK: - Namespace Environment Key

private struct NamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var namespace: Namespace.ID? {
        get { self[NamespaceKey.self] }
        set { self[NamespaceKey.self] = newValue }
    }
}
