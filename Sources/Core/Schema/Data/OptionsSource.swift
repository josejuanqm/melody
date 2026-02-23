//
//  OptionsSource.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Options for picker/menu: either a static array of options or a Lua expression
/// that returns an array of {label, value} tables at runtime.
public enum OptionsSource: Codable, Sendable, Equatable, Hashable {
    case `static`([OptionDefinition])
    case expression(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .expression(str)
        } else {
            let arr = try container.decode([OptionDefinition].self)
            self = .static(arr)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .static(let arr): try container.encode(arr)
        case .expression(let str): try container.encode(str)
        }
    }

    /// Returns static options, or nil if this is a dynamic expression.
    public var staticOptions: [OptionDefinition]? {
        if case .static(let arr) = self { return arr }
        return nil
    }

    /// Returns the Lua expression, or nil if this is static options.
    public var expressionString: String? {
        if case .expression(let str) = self { return str }
        return nil
    }

    /// Whether the options list is empty (static with no items). Expressions are never considered empty.
    public var isEmpty: Bool {
        if case .static(let arr) = self { return arr.isEmpty }
        return false
    }
}
