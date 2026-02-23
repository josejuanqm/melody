import Foundation

/// Schema for a plugin's `plugin.yaml` manifest file.
public struct PluginManifest: Codable, Sendable {
    public var name: String
    public var version: String?
    public var description: String?
    public var ios: PlatformConfig?
    public var android: PlatformConfig?
    public var lua: [String]?

    /// Platform-specific source files, frameworks, and dependencies for a plugin.
    public struct PlatformConfig: Codable, Sendable {
        public var sources: [String]
        public var frameworks: [String]?
        public var dependencies: [String]?
    }
}
