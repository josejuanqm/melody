//
//  WindowConfig.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Window sizing hints for macOS (minWidth, minHeight, idealWidth, idealHeight)
public struct WindowConfig: Codable, Sendable {
    public var minWidth: Double?
    public var minHeight: Double?
    public var idealWidth: Double?
    public var idealHeight: Double?

    public init(minWidth: Double? = nil, minHeight: Double? = nil,
                idealWidth: Double? = nil, idealHeight: Double? = nil) {
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.idealWidth = idealWidth
        self.idealHeight = idealHeight
    }
}
