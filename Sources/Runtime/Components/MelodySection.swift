import SwiftUI
import Core

/// Renders a section with optional header and footer inside a Form or List.
struct MelodySection<Content: View>: View {
    let definition: ComponentDefinition
    let resolvedLabel: String
    let resolvedFooter: String
    let headerContent: ComponentHeaderFooterContent?
    let footerContent: ComponentHeaderFooterContent?
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section {
            content()
        } header: {
            if case let .component(headerContent) = headerContent, !headerContent.isEmpty {
                ComponentRenderer(components: headerContent)
            } else if !resolvedLabel.isEmpty {
                Text(resolvedLabel)
            }
        } footer: {
            if case let .component(footerContent) = footerContent, !footerContent.isEmpty {
                ComponentRenderer(components: footerContent)
            } else if !resolvedFooter.isEmpty {
                Text(resolvedFooter)
            }
        }
    }
}
