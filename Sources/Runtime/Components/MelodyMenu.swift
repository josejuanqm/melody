import SwiftUI
import Core

/// Renders a pull-down menu with a label or SF Symbol trigger.
struct MelodyMenu<Content: View>: View {
    let definition: ComponentDefinition
    let resolvedLabel: String
    var resolvedSystemImage: String? = nil
    @ViewBuilder let content: () -> Content

    private var systemImage: String? {
        resolvedSystemImage ?? definition.systemImage?.literalValue
    }

    var body: some View {
        Menu {
            content()
        } label: {
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
    }
}
