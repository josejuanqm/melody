//
//  ContentInset.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Padding insets for screen content (no clipping, background, or other style effects)
public struct ContentInset: Codable, Sendable {
    public var top: Double?
    public var bottom: Double?
    public var leading: Double?
    public var trailing: Double?
    public var vertical: Double?
    public var horizontal: Double?

    public init(top: Double? = nil, bottom: Double? = nil,
                leading: Double? = nil, trailing: Double? = nil,
                vertical: Double? = nil, horizontal: Double? = nil) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
        self.vertical = vertical
        self.horizontal = horizontal
    }

    /// Resolved top inset (explicit top takes precedence over vertical shorthand)
    public var resolvedTop: Double { top ?? vertical ?? 0 }
    /// Resolved bottom inset
    public var resolvedBottom: Double { bottom ?? vertical ?? 0 }
    /// Resolved leading inset
    public var resolvedLeading: Double { leading ?? horizontal ?? 0 }
    /// Resolved trailing inset
    public var resolvedTrailing: Double { trailing ?? horizontal ?? 0 }
}
