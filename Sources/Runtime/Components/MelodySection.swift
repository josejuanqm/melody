import SwiftUI
import Core

/// Renders a section with optional header and footer inside a Form or List.
struct MelodySection<Content: View>: View {
    let definition: ComponentDefinition
    let resolvedLabel: String
    let resolvedFooter: String
    let headerContent: [ComponentDefinition]?
    let footerComponents: [ComponentDefinition]?
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section {
            content()
        } header: {
            if let headerContent, !headerContent.isEmpty {
                ComponentRenderer(components: headerContent)
            } else if !resolvedLabel.isEmpty {
                Text(resolvedLabel)
            }
        } footer: {
            if let footerComponents, !footerComponents.isEmpty {
                ComponentRenderer(components: footerComponents)
            } else if !resolvedFooter.isEmpty {
                Text(resolvedFooter)
            }
        }
    }
}
