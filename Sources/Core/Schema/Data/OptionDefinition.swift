//
//  OptionDefinition.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// An option for picker/menu components
public struct OptionDefinition: Codable, Sendable, Equatable, Hashable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}
