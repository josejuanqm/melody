import SwiftUI
import Core

/// View modifier that applies ``ComponentStyle`` properties to any SwiftUI view.
struct StyleModifier: ViewModifier {
    let style: ComponentStyle?
    @Environment(\.themeColors) private var themeColors
    @Environment(\.isInFormContext) private var isInFormContext

    func body(content: Content) -> some View {
        let padded = content
            .padding(.top, paddingTop)
            .padding(.bottom, paddingBottom)
            .padding(.leading, paddingLeading)
            .padding(.trailing, paddingTrailing)

        let resized = resized(content: padded)

        let framed = resized
            .frame(width: frameValue(style?.width.resolved),
                   height: frameValue(style?.height.resolved),
                   alignment: frameAlignment)
            .frame(minWidth: frameValue(style?.minWidth.resolved),
                   minHeight: frameValue(style?.minHeight.resolved),
                   alignment: frameAlignment)
            .frame(maxWidth: frameValue(style?.maxWidth.resolved),
                   maxHeight: frameValue(style?.maxHeight.resolved),
                   alignment: frameAlignment)

        let decorated = framed
            .opacity(style?.opacity.resolved ?? 1.0)
            .background(backgroundColor)


        let clipped = clipped(content: decorated)

        let overlayed = clipped
            .overlay(borderOverlay)
            .shadow(color: shadowColor,
                    radius: CGFloat(style?.shadow?.blur ?? 0) / 2,
                    x: CGFloat(style?.shadow?.x ?? 0),
                    y: CGFloat(style?.shadow?.y ?? 0))
            .scaleEffect(scaleValue)
            .rotationEffect(.degrees(rotationValue))

        let margined = overlayed
            .layoutPriority(style?.layoutPriority.resolved ?? 0)
            .padding(.top, marginTop)
            .padding(.bottom, marginBottom)
            .padding(.leading, marginLeading)
            .padding(.trailing, marginTrailing)

        if let anim = resolvedAnimation {
            margined.animation(anim, value: animationHash)
        } else {
            margined
        }
    }

    @ViewBuilder
    func clipped<T: View>(content: T) -> some View {
        if isInFormContext || cornerRadiusValue == 0 {
            content
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadiusValue))
        }
    }

    @ViewBuilder
    func resized<T: View>(content: T) -> some View {
        if let ratio = style?.aspectRatio.resolved {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(CGFloat(ratio), contentMode: contentMode)
        } else {
            content
        }
    }

    private var contentMode: ContentMode {
        if let mode = style?.contentMode {
            return ContentModeVariant(mode) == .fill ? .fill : .fit
        }
        return (style?.width != nil && style?.height != nil) ? .fill : .fit
    }

    // MARK: - Padding
    private var paddingTop: CGFloat { CGFloat(style?.paddingTop.resolved ?? style?.paddingVertical.resolved ?? style?.padding.resolved ?? 0) }
    private var paddingBottom: CGFloat { CGFloat(style?.paddingBottom.resolved ?? style?.paddingVertical.resolved ?? style?.padding.resolved ?? 0) }
    private var paddingLeading: CGFloat { CGFloat(style?.paddingLeft.resolved ?? style?.paddingHorizontal.resolved ?? style?.padding.resolved ?? 0) }
    private var paddingTrailing: CGFloat { CGFloat(style?.paddingRight.resolved ?? style?.paddingHorizontal.resolved ?? style?.padding.resolved ?? 0) }

    // MARK: - Margin
    private var marginTop: CGFloat { CGFloat(style?.marginTop.resolved ?? style?.marginVertical.resolved ?? style?.margin.resolved ?? 0) }
    private var marginBottom: CGFloat { CGFloat(style?.marginBottom.resolved ?? style?.marginVertical.resolved ?? style?.margin.resolved ?? 0) }
    private var marginLeading: CGFloat { CGFloat(style?.marginLeft.resolved ?? style?.marginHorizontal.resolved ?? style?.margin.resolved ?? 0) }
    private var marginTrailing: CGFloat { CGFloat(style?.marginRight.resolved ?? style?.marginHorizontal.resolved ?? style?.margin.resolved ?? 0) }

    private var frameAlignment: Alignment {
        switch style?.alignment?.literalValue {
        case .center: return .center
        case .leading, .left: return .leading
        case .trailing, .right: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        case .topLeading, .topLeft: return .topLeading
        case .topTrailing, .topRight: return .topTrailing
        case .bottomLeading, .bottomLeft: return .bottomLeading
        case .bottomTrailing, .bottomRight: return .bottomTrailing
        default: return .leading
        }
    }

    // MARK: - Transforms
    private var scaleValue: CGFloat { CGFloat(style?.scale.resolved ?? 1.0) }
    private var rotationValue: Double { style?.rotation.resolved ?? 0 }

    // MARK: - Animation
    private var resolvedAnimation: Animation? {
        StyleResolver.animation(style?.animation)
    }

    private var animationHash: AnimatableStyleHash {
        AnimatableStyleHash(
            scale: scaleValue,
            rotation: rotationValue,
            opacity: style?.opacity.resolved ?? 1.0,
            backgroundColor: style?.backgroundColor.resolved
        )
    }

    private func frameValue(_ value: Double?) -> CGFloat? {
        guard let v = value else { return nil }
        return v < 0 ? .infinity : CGFloat(v)
    }

    private var cornerRadiusValue: CGFloat {
        CGFloat(style?.cornerRadius.resolved ?? style?.borderRadius.resolved ?? 0)
    }

    private var backgroundColor: Color {
        if let value = style?.backgroundColor.resolved {
            return Color(hex: StyleResolver.colorHex(value, themeColors: themeColors))
        }
        return .clear
    }

    private var shadowColor: Color {
        if let value = style?.shadow?.color {
            return Color(hex: StyleResolver.colorHex(value, themeColors: themeColors))
        }
        return .clear
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if let borderWidth = style?.borderWidth.resolved, borderWidth > 0 {
            RoundedRectangle(cornerRadius: cornerRadiusValue)
                .stroke(
                    Color(hex: StyleResolver.colorHex(style?.borderColor.resolved ?? "#000000", themeColors: themeColors)),
                    lineWidth: CGFloat(borderWidth)
                )
        }
    }
}

extension View {
    func melodyStyle(_ style: ComponentStyle?) -> some View {
        modifier(StyleModifier(style: style))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Equatable snapshot of animatable style values used as a SwiftUI animation trigger.
struct AnimatableStyleHash: Equatable {
    let scale: CGFloat
    let rotation: Double
    let opacity: Double
    let backgroundColor: String?
}

/// Namespace for converting YAML style tokens (colors, weights, animations) into SwiftUI values.
enum StyleResolver {
    static func colorHex(_ value: String, themeColors: [String: String]) -> String {
        if value.hasPrefix("theme.") {
            let key = String(value.dropFirst(6))
            return themeColors[key] ?? value
        }
        return value
    }

    static func color(from style: ComponentStyle?, default defaultColor: Color, themeColors: [String: String]) -> Color {
        guard let value = style?.color.resolved else { return defaultColor }
        return Color(hex: colorHex(value, themeColors: themeColors))
    }

    static func fontWeight(_ weight: String?) -> Font.Weight {
        switch weight?.lowercased() {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        case "thin": return .thin
        case "heavy": return .heavy
        case "black": return .black
        case "ultralight": return .ultraLight
        default: return .regular
        }
    }

    static func fontDesign(_ design: String?) -> Font.Design {
        switch design?.lowercased() {
        case "monospaced", "mono": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return .default
        }
    }

    static func animation(_ name: String?) -> Animation? {
        guard let name = name?.lowercased() else { return nil }
        switch name {
        case "easeinout": return .easeInOut(duration: 0.2)
        case "easein": return .easeIn(duration: 0.2)
        case "easeout": return .easeOut(duration: 0.2)
        case "linear": return .linear(duration: 0.2)
        case "spring": return .spring(response: 0.3, dampingFraction: 0.7)
        case "bouncy": return .spring(response: 0.3, dampingFraction: 0.5)
        case "smooth": return .smooth(duration: 0.25)
        default: return .default
        }
    }
}
