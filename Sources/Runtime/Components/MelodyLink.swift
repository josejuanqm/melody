import SwiftUI
import Core

/// Renders an external URL link with a text or SF Symbol label.
struct MelodyLink: View {
    let definition: ComponentDefinition
    let resolvedLabel: String
    let resolvedURL: String
    var resolvedSystemImage: String? = nil

    private var systemImage: String? {
        resolvedSystemImage ?? definition.systemImage?.literalValue
    }

    var body: some View {
        if let url = URL(string: resolvedURL) {
            Link(destination: url) {
                if let systemImage {
                    if resolvedLabel.isEmpty {
                        Image(systemName: systemImage)
                    } else {
                        Label(resolvedLabel, systemImage: systemImage)
                    }
                } else {
                    Text(resolvedLabel)
                }
            }
            .melodyStyle(definition.style)
        } else {
            Text(resolvedLabel)
                .melodyStyle(definition.style)
        }
    }
}
