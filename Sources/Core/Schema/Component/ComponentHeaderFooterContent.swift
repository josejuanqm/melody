//
//  ComponentHeader.swift
//  Melody
//
//  Created by Jose Quintero on 24/02/26.
//

import SwiftUI

public indirect enum ComponentHeaderFooterContent: Codable, Sendable, Hashable, Equatable {
    case string(Value<String>)
    case component([ComponentDefinition])

    public var expressionValue: String? {
        if case .string(let s) = self, case .expression(let e) = s { return e }
        return nil
    }

    public init(from decoder: any Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            let stringValue = try container.decode(Value<String>.self)
            self = .string(stringValue)
        } catch {
            self = .component(try [ComponentDefinition].self.init(from: decoder))
        }
    }
}
