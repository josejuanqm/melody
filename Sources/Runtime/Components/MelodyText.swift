import SwiftUI
import Core

/// Renders a styled text label from a resolved string value.
struct MelodyText: View {
    let definition: ComponentDefinition
    let resolvedText: String
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        Text(resolvedText)
            .font(.system(size: CGFloat(definition.style?.fontSize.resolved ?? 16),
                          weight: StyleResolver.fontWeight(definition.style?.fontWeight),
                          design: StyleResolver.fontDesign(definition.style?.fontDesign)))
            .foregroundStyle(textColor)
            .multilineTextAlignment(textAlignment)
            .lineLimit(definition.style?.lineLimit.resolved)
            .melodyStyle(definition.style)
    }

    private var textAlignment: TextAlignment {
        switch definition.style?.alignment?.literalValue {
        case .center: return .center
        case .trailing, .right: return .trailing
        default: return .leading
        }
    }

    private var textColor: Color {
        StyleResolver.color(from: definition.style, default: .primary, themeColors: themeColors)
    }
}
