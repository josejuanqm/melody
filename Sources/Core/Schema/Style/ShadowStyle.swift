//
//  ShadowStyle.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Shadow effect parameters (offset, blur radius, color) applied to a component.
public struct ShadowStyle: Codable, Sendable, Equatable, Hashable {
    public var x: Double?
    public var y: Double?
    public var blur: Double?
    public var color: String?

    public init(x: Double? = nil, y: Double? = nil, blur: Double? = nil, color: String? = nil) {
        self.x = x
        self.y = y
        self.blur = blur
        self.color = color
    }
}
