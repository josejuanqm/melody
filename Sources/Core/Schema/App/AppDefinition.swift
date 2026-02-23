//
//  AppConfig.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Top-level app definition parsed from YAML
public struct AppDefinition: Codable, Sendable {
    public var app: AppConfig
    public var screens: [ScreenDefinition] = []
    public var components: [String: CustomComponentDefinition]?

    public init(app: AppConfig, screens: [ScreenDefinition] = [], components: [String: CustomComponentDefinition]? = nil) {
        self.app = app
        self.screens = screens
        self.components = components
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try container.decode(AppConfig.self, forKey: .app)
        self.screens = try container.decodeIfPresent([ScreenDefinition].self, forKey: .screens) ?? []
        self.components = try container.decodeIfPresent([String : CustomComponentDefinition].self, forKey: .components)
    }
}
