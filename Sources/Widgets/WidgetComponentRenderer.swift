#if canImport(SwiftUI)
import SwiftUI
import Core

/// Renders resolved ComponentDefinition trees as SwiftUI views for WidgetKit.
public struct WidgetComponentRenderer: View {

    let components: [ComponentDefinition]
    let themeColors: [String: String]

    public init(components: [ComponentDefinition], themeColors: [String: String] = [:]) {
        self.components = components
        self.themeColors = themeColors
    }

    public var body: some View {
        ForEach(Array(components.enumerated()), id: \.offset) { _, component in
            WidgetComponentView(component: component, themeColors: themeColors)
        }
    }
}

struct WidgetComponentView: View {

    let component: ComponentDefinition
    let themeColors: [String: String]

    var body: some View {
        componentContent
            .widgetStyle(component.style, themeColors: themeColors)
    }

    @ViewBuilder
    private var componentContent: some View {
        switch component.component {
        case "text":
            textView
        case "stack":
            stackView
        case "image":
            imageView
        case "button":
            buttonView
        case "spacer":
            Spacer()
        case "divider":
            Divider()
        case "progress":
            progressView
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var textView: some View {
        let content = component.text?.literalValue ?? ""
        let color = component.style?.color?.literalValue
        Text(content)
            .font(resolveFont(style: component.style))
            .foregroundStyle(color.map { resolveColor($0, themeColors: themeColors) } ?? .primary)
            .lineLimit(component.style?.lineLimit?.literalValue)
    }

    @ViewBuilder
    private var stackView: some View {
        let spacing: CGFloat? = component.style?.spacing.resolved.map { CGFloat($0) }
        let children = component.children ?? []
        let direction = component.direction?.literalValue
        let alignment = component.style?.alignment?.literalValue

        switch direction {
        case .horizontal:
            HStack(alignment: resolveVerticalAlignment(alignment), spacing: spacing) {
                WidgetComponentRenderer(components: children, themeColors: themeColors)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .stacked:
            ZStack(alignment: resolveZAlignment(alignment)) {
                WidgetComponentRenderer(components: children, themeColors: themeColors)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            VStack(alignment: resolveHorizontalAlignment(alignment), spacing: spacing) {
                WidgetComponentRenderer(components: children, themeColors: themeColors)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let name = component.systemImage?.literalValue {
            let color = component.style?.color?.literalValue
            let size = component.style?.fontSize.resolved ?? component.style?.width.resolved ?? component.style?.height.resolved ?? 16
            Image(systemName: name)
                .font(.system(size: size))
                .foregroundStyle(color.map { resolveColor($0, themeColors: themeColors) } ?? .primary)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var buttonView: some View {
        if let urlString = component.url?.literalValue, let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 6) {
                    if let icon = component.systemImage?.literalValue {
                        Image(systemName: icon)
                    }
                    if let label = component.label?.literalValue {
                        Text(label)
                    }
                }
                .font(resolveFont(style: component.style))
                .foregroundStyle(
                    component.style?.color?.literalValue.map { resolveColor($0, themeColors: themeColors) } ?? .white
                )
            }
        } else {
            HStack(spacing: 6) {
                if let icon = component.systemImage?.literalValue {
                    Image(systemName: icon)
                }
                if let label = component.label?.literalValue {
                    Text(label)
                }
            }
            .font(resolveFont(style: component.style))
            .foregroundStyle(
                component.style?.color?.literalValue.map { resolveColor($0, themeColors: themeColors) } ?? .white
            )
        }
    }

    @ViewBuilder
    private var progressView: some View {
        if let valueStr = component.value?.literalValue, let value = Double(valueStr) {
            ProgressView(value: value)
        } else {
            ProgressView()
        }
    }
}

// MARK: - Alignment Helpers

private func resolveVerticalAlignment(_ alignment: ViewAlignment?) -> VerticalAlignment {
    switch alignment {
    case .top, .topLeading, .topLeft, .topTrailing, .topRight: return .top
    case .bottom, .bottomLeading, .bottomLeft, .bottomTrailing, .bottomRight: return .bottom
    default: return .center
    }
}

private func resolveHorizontalAlignment(_ alignment: ViewAlignment?) -> HorizontalAlignment {
    switch alignment {
    case .leading, .left, .topLeading, .topLeft, .bottomLeading, .bottomLeft: return .leading
    case .trailing, .right, .topTrailing, .topRight, .bottomTrailing, .bottomRight: return .trailing
    default: return .center
    }
}

private func resolveZAlignment(_ alignment: ViewAlignment?) -> Alignment {
    switch alignment {
    case .center: return .center
    case .top: return .top
    case .bottom: return .bottom
    case .leading, .left: return .leading
    case .trailing, .right: return .trailing
    case .topLeading, .topLeft: return .topLeading
    case .topTrailing, .topRight: return .topTrailing
    case .bottomLeading, .bottomLeft: return .bottomLeading
    case .bottomTrailing, .bottomRight: return .bottomTrailing
    default: return .center
    }
}
#endif
