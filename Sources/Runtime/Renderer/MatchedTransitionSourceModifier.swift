//
//  MatchedTransitionSourceModifier.swift
//  Melody
//
//  Created by Jose Quintero on 20/02/26.
//

import SwiftUI

public struct MatchedTransitionSourceModifier<ID: Hashable>: ViewModifier {
    let namespace: Namespace.ID?
    let usesSharedObjectTransition: Bool
    let hashable: ID

    public func body(content: Content) -> some View {
        if let namespace, usesSharedObjectTransition {
#if os(macOS)
            if #available(macOS 15.0, *) {
                    content
                        .matchedTransitionSource(id: hashable, in: namespace)
            } else {
                content
            }
#elseif os(iOS)
            if #available(iOS 18.0, *) {
                    content
                        .matchedTransitionSource(id: hashable, in: namespace)
            } else {
                content
            }
#endif
        } else {
            content
        }
    }
}
