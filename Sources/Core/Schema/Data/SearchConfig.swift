//
//  SearchConfig.swift
//  Melody
//
//  Created by Jose Quintero on 19/02/26.
//

import Foundation

/// Configuration for native `.searchable()` modifier on a screen
public struct SearchConfig: Codable, Sendable {
    public var stateKey: String
    public var prompt: String?
    public var onSubmit: String?
    /// Toolbar placement for the search field (e.g., "bottomBar").
    /// On iOS 26+ this uses DefaultToolbarItem(kind: .search). Ignored on older versions.
    public var placement: String?
    /// When true, minimizes the search field into a toolbar button (iOS 26+).
    public var minimized: Bool?

    public init(stateKey: String, prompt: String? = nil, onSubmit: String? = nil,
                placement: String? = nil, minimized: Bool? = nil) {
        self.stateKey = stateKey
        self.prompt = prompt
        self.onSubmit = onSubmit
        self.placement = placement
        self.minimized = minimized
    }
}
