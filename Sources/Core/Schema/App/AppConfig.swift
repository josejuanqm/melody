//
//  AppConfig.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Top-level application configuration parsed from `app.yaml`.
public struct AppConfig: Codable, Sendable {
    public var name: String
    public var id: String?
    public var theme: ThemeConfig?
    public var window: WindowConfig?
    public var lua: String?
    /// Plugin declarations: name → git URL. Used by the CLI for resolution;
    /// parsed but not used at runtime.
    public var plugins: [String: String]?

    public init(name: String, id: String? = nil, theme: ThemeConfig? = nil, window: WindowConfig? = nil, lua: String? = nil, plugins: [String: String]? = nil) {
        self.name = name
        self.id = id
        self.theme = theme
        self.window = window
        self.lua = lua
        self.plugins = plugins
    }
}
