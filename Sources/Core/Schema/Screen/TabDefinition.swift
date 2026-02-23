//
//  TabDefinition.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Configuration for a single tab in a tab-based navigation screen.
public struct TabDefinition: Codable, Sendable {
    public var id: String
    public var title: String
    public var icon: String
    public var screen: String
    /// When set, the tab is only visible on the listed platforms (e.g. `["ios", "macos"]`).
    /// Valid values: `"ios"`, `"android"`, `"macos"` (alias: `"desktop"`).
    /// If nil or empty, the tab is visible on all platforms.
    public var platforms: [String]?
    /// Sidebar group name. Consecutive tabs with the same `group` are rendered
    /// inside a `TabSection` when using `sidebarAdaptable` tab style.
    /// Ignored in standard tab bar mode and on Android.
    public var group: String?
    /// Controls dynamic visibility. Can be a literal bool or a `{{ Lua expression }}`.
    /// When the expression returns `false` or `nil`, the tab is hidden.
    /// The expression has access to `melody.storeGet()` and `platform`.
    public var visible: Value<Bool>?

    public init(id: String, title: String, icon: String, screen: String,
                platforms: [String]? = nil, group: String? = nil, visible: Value<Bool>? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.screen = screen
        self.platforms = platforms
        self.group = group
        self.visible = visible
    }
}
