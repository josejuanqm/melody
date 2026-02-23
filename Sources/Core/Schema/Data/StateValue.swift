//
//  StateValue.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// A state value that can be a string, number, bool, null, or nested structure
public enum StateValue: Codable, Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([StateValue])
    case dictionary([String: StateValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([StateValue].self) {
            self = .array(arr)
        } else if let dict = try? container.decode([String: StateValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.typeMismatch(
                StateValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported state value type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        case .array(let arr): try container.encode(arr)
        case .dictionary(let dict): try container.encode(dict)
        }
    }
}
