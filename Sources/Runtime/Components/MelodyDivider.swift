import SwiftUI
import Core

/// Renders a horizontal divider line.
struct MelodyDivider: View {
    let definition: ComponentDefinition

    var body: some View {
        Divider()
            .melodyStyle(definition.style)
    }
}
