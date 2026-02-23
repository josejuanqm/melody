//
//  NavigationTransitionModifier.swift
//  Melody
//
//  Created by Jose Quintero on 20/02/26.
//

import SwiftUI

@available(tvOS 18.0, *)
@available(macOS 15.0, *)
@available(iOS 18.0, *)
public struct NavigationTransitionModifier<T: NavigationTransition>: ViewModifier {
    let shouldApplyTransition: Bool
    let navigationType: T

    public func body(content: Content) -> some View {
        if shouldApplyTransition {
            content.navigationTransition(navigationType)
        } else {
            content
        }
    }
}
