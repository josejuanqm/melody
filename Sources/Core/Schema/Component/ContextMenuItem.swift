//
//  ContextMenuItem.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// A menu item for context menus (long press)
public struct ContextMenuItem: Codable, Sendable, Equatable, Hashable {
    public var label: String
    public var systemImage: String?
    public var style: String?
    public var onTap: String?
    public var section: Bool?

    public init(label: String, systemImage: String? = nil, style: String? = nil, onTap: String? = nil, section: Bool? = nil) {
        self.label = label
        self.systemImage = systemImage
        self.style = style
        self.onTap = onTap
        self.section = section
    }
}
