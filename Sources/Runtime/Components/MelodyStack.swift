import SwiftUI
import Core

/// Renders a Stack (VStack/HStack) component
struct MelodyStack<Content: View>: View {
    let definition: ComponentDefinition
    let resolvedDirection: DirectionAxis
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            switch resolvedDirection {
            case .horizontal:
                if isLazy {
                    LazyHStack(alignment: verticalAlignment, spacing: spacing) {
                        content()
                    }
                    .frame(maxHeight: hasExplicitHeight || !shouldGrowToFitParent ? nil : .infinity)
                } else {
                    HStack(alignment: verticalAlignment, spacing: spacing) {
                        content()
                    }
                    .frame(maxHeight: hasExplicitHeight || !shouldGrowToFitParent ? nil : .infinity)
                }
            case .stacked:
                ZStack(alignment: zAlignment) {
                    content()
                }
            case .vertical:
                if isLazy {
                    LazyVStack(alignment: horizontalAlignment, spacing: spacing) {
                        content()
                    }
                    .frame(maxWidth: hasExplicitWidth || !shouldGrowToFitParent ? nil : .infinity, alignment: zAlignment)
                } else {
                    VStack(alignment: horizontalAlignment, spacing: spacing) {
                        content()
                    }
                    .frame(maxWidth: hasExplicitWidth || !shouldGrowToFitParent ? nil : .infinity, alignment: zAlignment)
                }
            }
        }
        .melodyStyle(definition.style)
        .environment(\.isInStackContext, true)
    }

    private var isLazy: Bool {
        definition.lazy ?? false
    }

    private var shouldGrowToFitParent: Bool {
        definition.shouldGrowToFitParent ?? false
    }

    private var hasExplicitWidth: Bool {
        definition.style?.width != nil || definition.style?.maxWidth != nil
    }

    private var hasExplicitHeight: Bool {
        definition.style?.height != nil || definition.style?.maxHeight != nil
    }

    private var spacing: CGFloat? {
        definition.style?.spacing.resolved.map { CGFloat($0) }
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch definition.style?.alignment?.literalValue {
        case .leading, .left, .topLeading, .topLeft, .bottomLeading, .bottomLeft:
            return .leading
        case .trailing, .right, .topTrailing, .topRight, .bottomTrailing, .bottomRight:
            return .trailing
        default: return .center
        }
    }

    private var verticalAlignment: VerticalAlignment {
        switch definition.style?.alignment?.literalValue {
        case .top, .topLeading, .topLeft, .topTrailing, .topRight:
            return .top
        case .bottom, .bottomLeading, .bottomLeft, .bottomTrailing, .bottomRight:
            return .bottom
        default: return .center
        }
    }

    private var zAlignment: Alignment {
        switch definition.style?.alignment?.literalValue {
        case .center: return .center
        case .leading, .left: return .leading
        case .trailing, .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        case .topLeading, .topLeft: return .topLeading
        case .topTrailing, .topRight: return .topTrailing
        case .bottomLeading, .bottomLeft: return .bottomLeading
        case .bottomTrailing, .bottomRight: return .bottomTrailing
        default: return .center
        }
    }
}
