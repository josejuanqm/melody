import SwiftUI
import Core

/// Renders a SwiftUI Form container with configurable form style.
struct MelodyForm<Content: View>: View {
    let definition: ComponentDefinition
    @ViewBuilder let content: () -> Content

    var body: some View {
        let form = Form {
            content()
        }
        .environment(\.isInFormContext, true)
        .frame(maxHeight: definition.style?.height == nil ? .infinity : nil)

        switch FormVariant(definition.formStyle) {
        case .grouped:
            form.formStyle(.grouped)
                .melodyStyle(definition.style)
        case .columns:
            #if os(macOS)
            form.formStyle(.columns)
                .melodyStyle(definition.style)
            #else
            form.formStyle(.grouped)
                .melodyStyle(definition.style)
            #endif
        case .automatic:
            form.formStyle(.automatic)
                .melodyStyle(definition.style)
        }
    }
}
