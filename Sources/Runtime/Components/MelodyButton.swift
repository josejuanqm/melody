import SwiftUI
import Core

/// Renders a tappable button with an optional SF Symbol and styled label.
struct MelodyButton: View {
    @Environment(\.themeColors) private var themeColors
    @Environment(\.isInFormContext) private var isInFormContext

    let definition: ComponentDefinition
    let resolvedLabel: String
    var resolvedSystemImage: String? = nil
    let onTap: () -> Void

    var body: some View {
        if let systemImage, resolvedLabel.isEmpty, definition.style == nil {
            Button(action: onTap) {
                Image(systemName: systemImage)
            }
        } else {
            Button(action: onTap) {
                Group {
                    if let systemImage {
                        if resolvedLabel.isEmpty {
                            Image(systemName: systemImage)
                                .foregroundStyle(textColor)
                        } else {
                            Label(resolvedLabel, systemImage: systemImage)
                                .font(.system(size: CGFloat(definition.style?.fontSize.resolved ?? 16),
                                              weight: StyleResolver.fontWeight(definition.style?.fontWeight),
                                              design: StyleResolver.fontDesign(definition.style?.fontDesign)))
                                .foregroundStyle(textColor)
                                .frame(maxWidth: definition.style?.backgroundColor != nil ? .infinity : nil,
                                       alignment: frameAlignment)
                        }
                    } else {
                        Text(resolvedLabel)
                            .font(.system(size: CGFloat(definition.style?.fontSize.resolved ?? 16),
                                          weight: StyleResolver.fontWeight(definition.style?.fontWeight),
                                          design: StyleResolver.fontDesign(definition.style?.fontDesign)))
                            .foregroundStyle(textColor)
                            .frame(maxWidth: definition.style?.backgroundColor != nil ? .infinity : nil,
                                   alignment: frameAlignment)
                    }
                }
                .melodyStyle(definition.style)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var frameAlignment: Alignment {
        switch definition.style?.alignment?.literalValue {
        case .leading, .left: return .leading
        case .trailing, .right: return .trailing
        default: return .center
        }
    }

    private var textColor: Color {
        StyleResolver.color(from: definition.style, default: .accentColor, themeColors: themeColors)
    }

    private var systemImage: String? {
        resolvedSystemImage ?? definition.systemImage?.literalValue
    }
}
