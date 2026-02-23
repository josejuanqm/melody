//
//  ComponentRef.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//


/// Heap-allocated wrapper for ComponentDefinition, enabling recursive references
/// (e.g. `background`) without infinite struct size.
public final class ComponentRef: Codable, Sendable, Equatable, Hashable {
    public static func == (lhs: ComponentRef, rhs: ComponentRef) -> Bool {
        lhs.wrapped == rhs.wrapped
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }

    public let wrapped: ComponentDefinition

    public init(_ component: ComponentDefinition) {
        self.wrapped = component
    }

    public init(from decoder: Decoder) throws {
        self.wrapped = try ComponentDefinition(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}
