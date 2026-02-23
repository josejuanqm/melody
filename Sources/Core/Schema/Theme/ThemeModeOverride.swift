//
//  ThemeModeOverride.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Per-appearance (light/dark) color overrides within a theme.
public struct ThemeModeOverride: Codable, Sendable {
    public var primary: String?
    public var secondary: String?
    public var background: String?
    public var colors: [String: String]?

    public init(primary: String? = nil, secondary: String? = nil, background: String? = nil, colors: [String: String]? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.background = background
        self.colors = colors
    }
}
