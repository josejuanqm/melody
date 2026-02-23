//
//  CustomComponentDefinition.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

/// A reusable component template with typed props and a body
public struct CustomComponentDefinition: Codable, Sendable {
    public var name: String?
    public var props: [String: StateValue]?
    public var body: [ComponentDefinition]

    public init(name: String? = nil, props: [String: StateValue]? = nil, body: [ComponentDefinition]) {
        self.name = name
        self.props = props
        self.body = body
    }
}
