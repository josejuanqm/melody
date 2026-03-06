#if canImport(SwiftUI)
import SwiftUI
import Core

/// Simplified style application for widget context.
struct WidgetStyleModifier: ViewModifier {

    let style: ComponentStyle?
    let themeColors: [String: String]

    func body(content: Content) -> some View {
        content
            .applyPadding(style)
            .applySize(style)
            .applyMaxSize(style)
            .applyBackground(style, themeColors: themeColors)
            .applyCornerRadius(style)
            .applyOpacity(style)
    }
}

extension View {

    func widgetStyle(_ style: ComponentStyle?, themeColors: [String: String] = [:]) -> some View {
        modifier(WidgetStyleModifier(style: style, themeColors: themeColors))
    }

    @ViewBuilder
    func applyPadding(_ style: ComponentStyle?) -> some View {
        if let style {
            let top = style.paddingTop.resolved ?? style.paddingVertical.resolved ?? style.padding.resolved ?? 0
            let bottom = style.paddingBottom.resolved ?? style.paddingVertical.resolved ?? style.padding.resolved ?? 0
            let leading = style.paddingLeft.resolved ?? style.paddingHorizontal.resolved ?? style.padding.resolved ?? 0
            let trailing = style.paddingRight.resolved ?? style.paddingHorizontal.resolved ?? style.padding.resolved ?? 0
            if top > 0 || bottom > 0 || leading > 0 || trailing > 0 {
                self.padding(EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
            } else {
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applySize(_ style: ComponentStyle?) -> some View {
        if let style {
            let w = style.width.resolved
            let h = style.height.resolved
            switch (w, h) {
            case (.some(let w), .some(let h)) where w == -1 && h == -1:
                self.frame(maxWidth: .infinity, maxHeight: .infinity)
            case (.some(let w), .some(let h)) where w == -1:
                self.frame(maxWidth: .infinity, minHeight: h, idealHeight: h, maxHeight: h)
            case (.some(let w), .some(let h)) where h == -1:
                self.frame(minWidth: w, idealWidth: w, maxWidth: w, maxHeight: .infinity)
            case (.some(let w), .some(let h)):
                self.frame(width: w, height: h)
            case (.some(let w), nil) where w == -1:
                self.frame(maxWidth: .infinity)
            case (.some(let w), nil):
                self.frame(width: w)
            case (nil, .some(let h)) where h == -1:
                self.frame(maxHeight: .infinity)
            case (nil, .some(let h)):
                self.frame(height: h)
            default:
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyMaxSize(_ style: ComponentStyle?) -> some View {
        if let style {
            let mw = style.maxWidth.resolved
            let mh = style.maxHeight.resolved
            switch (mw, mh) {
            case (.some(let w), .some(let h)) where w == -1 && h == -1:
                self.frame(maxWidth: .infinity, maxHeight: .infinity)
            case (.some(let w), _) where w == -1:
                self.frame(maxWidth: .infinity)
            case (_, .some(let h)) where h == -1:
                self.frame(maxHeight: .infinity)
            case (.some(let w), .some(let h)):
                self.frame(maxWidth: w, maxHeight: h)
            case (.some(let w), nil):
                self.frame(maxWidth: w)
            case (nil, .some(let h)):
                self.frame(maxHeight: h)
            default:
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyBackground(_ style: ComponentStyle?, themeColors: [String: String]) -> some View {
        if let bg = style?.backgroundColor?.literalValue {
            self.background(resolveColor(bg, themeColors: themeColors))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyCornerRadius(_ style: ComponentStyle?) -> some View {
        let cr = style?.cornerRadius.resolved ?? style?.borderRadius.resolved
        if let cr, cr > 0 {
            self.clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyOpacity(_ style: ComponentStyle?) -> some View {
        if let o = style?.opacity.resolved {
            self.opacity(o)
        } else {
            self
        }
    }
}

func resolveColor(_ colorString: String, themeColors: [String: String] = [:]) -> Color {
    if colorString.hasPrefix("theme.") {
        let key = String(colorString.dropFirst(6))
        if let hex = themeColors[key] {
            return Color(hex: hex)
        }
        return .primary
    }
    return Color(hex: colorString)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

func resolveFont(style: ComponentStyle?) -> Font {
    let size = style?.fontSize.resolved ?? 14
    var font = Font.system(size: size)
    if let weight = style?.fontWeight {
        font = font.weight(resolveFontWeight(weight))
    }
    return font
}

func resolveFontWeight(_ weight: String) -> Font.Weight {
    switch weight.lowercased() {
    case "ultralight": return .ultraLight
    case "thin": return .thin
    case "light": return .light
    case "regular": return .regular
    case "medium": return .medium
    case "semibold": return .semibold
    case "bold": return .bold
    case "heavy": return .heavy
    case "black": return .black
    default: return .regular
    }
}
#endif
