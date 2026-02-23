//
//  ThemeConfig.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Color theme and appearance settings for the application.
public struct ThemeConfig: Codable, Sendable {
    public var primary: String?
    public var secondary: String?
    public var background: String?
    public var colorScheme: String?
    public var colors: [String: String]?
    public var dark: ThemeModeOverride?
    public var light: ThemeModeOverride?

    public init(primary: String? = nil, secondary: String? = nil, background: String? = nil, colorScheme: String? = nil, colors: [String: String]? = nil, dark: ThemeModeOverride? = nil, light: ThemeModeOverride? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.background = background
        self.colorScheme = colorScheme
        self.colors = colors
        self.dark = dark
        self.light = light
    }
}
