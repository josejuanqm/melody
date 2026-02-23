import SwiftUI

/// Holds all registered ``MelodyPlugin`` instances and bulk-registers them on new VMs.
public final class MelodyPluginRegistry: @unchecked Sendable {
    private let plugins: [MelodyPlugin]

    public init(plugins: [MelodyPlugin] = []) {
        self.plugins = plugins
    }

    /// Register all plugin functions on the given VM.
    public func register(on vm: LuaVM) {
        for plugin in plugins {
            plugin.register(vm: vm)
        }
    }
}

// MARK: - Environment Key

private struct PluginRegistryKey: EnvironmentKey {
    static let defaultValue: MelodyPluginRegistry? = nil
}

extension EnvironmentValues {
    public var pluginRegistry: MelodyPluginRegistry? {
        get { self[PluginRegistryKey.self] }
        set { self[PluginRegistryKey.self] = newValue }
    }
}
