import SwiftUI
import Core

struct MelodyDisclosure<Content: View>: View {
    let definition: ComponentDefinition
    let resolvedLabel: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        #if os(tvOS)
        VStack {
            content()
        }
        .melodyStyle(definition.style)
        #else
        DisclosureGroup(resolvedLabel) {
            content()
        }
        .melodyStyle(definition.style)
        #endif
    }
}
