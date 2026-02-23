import Foundation

/// Visual styling properties (layout, spacing, colors, typography) applied to a component.
public struct ComponentStyle: Codable, Sendable, Equatable, Hashable {
    public var fontSize: Value<Double>?
    public var padding: Value<Double>?
    public var paddingTop: Value<Double>?
    public var paddingBottom: Value<Double>?
    public var paddingLeft: Value<Double>?
    public var paddingRight: Value<Double>?
    public var paddingHorizontal: Value<Double>?
    public var paddingVertical: Value<Double>?
    public var margin: Value<Double>?
    public var marginTop: Value<Double>?
    public var marginBottom: Value<Double>?
    public var marginLeft: Value<Double>?
    public var marginRight: Value<Double>?
    public var marginHorizontal: Value<Double>?
    public var marginVertical: Value<Double>?
    public var borderRadius: Value<Double>?
    public var borderWidth: Value<Double>?
    public var width: Value<Double>?
    public var height: Value<Double>?
    public var minWidth: Value<Double>?
    public var minHeight: Value<Double>?
    public var maxWidth: Value<Double>?
    public var maxHeight: Value<Double>?
    public var spacing: Value<Double>?
    public var opacity: Value<Double>?
    public var cornerRadius: Value<Double>?
    public var scale: Value<Double>?
    public var rotation: Value<Double>?
    public var aspectRatio: Value<Double>?
    public var layoutPriority: Value<Double>?

    public var color: Value<String>?
    public var backgroundColor: Value<String>?
    public var borderColor: Value<String>?

    public var alignment: Value<ViewAlignment>?

    public var lineLimit: Value<Int>?

    public var fontWeight: String?
    public var fontDesign: String?
    public var shadow: ShadowStyle?
    public var animation: String?
    public var contentMode: String?
    public var overflow: String?

    private enum CodingKeys: String, CodingKey {
        case fontSize, fontWeight, fontDesign, color, backgroundColor
        case padding, paddingTop, paddingBottom, paddingLeft, paddingRight, paddingHorizontal, paddingVertical
        case margin, marginTop, marginBottom, marginLeft, marginRight, marginHorizontal, marginVertical
        case borderRadius, borderWidth, borderColor
        case width, height, minWidth, minHeight, maxWidth, maxHeight
        case spacing, alignment, shadow, opacity, cornerRadius
        case scale, rotation, animation, aspectRatio, contentMode, overflow, lineLimit, layoutPriority
    }

    public init(
        fontSize: Value<Double>? = nil,
        fontWeight: String? = nil,
        fontDesign: String? = nil,
        color: Value<String>? = nil,
        backgroundColor: Value<String>? = nil,
        padding: Value<Double>? = nil,
        paddingTop: Value<Double>? = nil,
        paddingBottom: Value<Double>? = nil,
        paddingLeft: Value<Double>? = nil,
        paddingRight: Value<Double>? = nil,
        paddingHorizontal: Value<Double>? = nil,
        paddingVertical: Value<Double>? = nil,
        margin: Value<Double>? = nil,
        marginTop: Value<Double>? = nil,
        marginBottom: Value<Double>? = nil,
        marginLeft: Value<Double>? = nil,
        marginRight: Value<Double>? = nil,
        marginHorizontal: Value<Double>? = nil,
        marginVertical: Value<Double>? = nil,
        borderRadius: Value<Double>? = nil,
        borderWidth: Value<Double>? = nil,
        borderColor: Value<String>? = nil,
        width: Value<Double>? = nil,
        height: Value<Double>? = nil,
        minWidth: Value<Double>? = nil,
        minHeight: Value<Double>? = nil,
        maxWidth: Value<Double>? = nil,
        maxHeight: Value<Double>? = nil,
        spacing: Value<Double>? = nil,
        alignment: Value<ViewAlignment>? = nil,
        shadow: ShadowStyle? = nil,
        opacity: Value<Double>? = nil,
        cornerRadius: Value<Double>? = nil,
        scale: Value<Double>? = nil,
        rotation: Value<Double>? = nil,
        animation: String? = nil,
        aspectRatio: Value<Double>? = nil,
        contentMode: String? = nil,
        overflow: String? = nil,
        lineLimit: Value<Int>? = nil,
        layoutPriority: Value<Double>? = nil
    ) {
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.fontDesign = fontDesign
        self.color = color
        self.backgroundColor = backgroundColor
        self.padding = padding
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
        self.paddingHorizontal = paddingHorizontal
        self.paddingVertical = paddingVertical
        self.margin = margin
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.marginLeft = marginLeft
        self.marginRight = marginRight
        self.marginHorizontal = marginHorizontal
        self.marginVertical = marginVertical
        self.borderRadius = borderRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.spacing = spacing
        self.alignment = alignment
        self.shadow = shadow
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.scale = scale
        self.rotation = rotation
        self.animation = animation
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.overflow = overflow
        self.lineLimit = lineLimit
        self.layoutPriority = layoutPriority
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = Value.yamlDecode(from: c, key: .fontSize)
        fontWeight = try c.decodeIfPresent(String.self, forKey: .fontWeight)
        fontDesign = try c.decodeIfPresent(String.self, forKey: .fontDesign)
        color = try c.decodeIfPresent(Value<String>.self, forKey: .color)
        backgroundColor = try c.decodeIfPresent(Value<String>.self, forKey: .backgroundColor)
        padding = Value.yamlDecode(from: c, key: .padding)
        paddingTop = Value.yamlDecode(from: c, key: .paddingTop)
        paddingBottom = Value.yamlDecode(from: c, key: .paddingBottom)
        paddingLeft = Value.yamlDecode(from: c, key: .paddingLeft)
        paddingRight = Value.yamlDecode(from: c, key: .paddingRight)
        paddingHorizontal = Value.yamlDecode(from: c, key: .paddingHorizontal)
        paddingVertical = Value.yamlDecode(from: c, key: .paddingVertical)
        margin = Value.yamlDecode(from: c, key: .margin)
        marginTop = Value.yamlDecode(from: c, key: .marginTop)
        marginBottom = Value.yamlDecode(from: c, key: .marginBottom)
        marginLeft = Value.yamlDecode(from: c, key: .marginLeft)
        marginRight = Value.yamlDecode(from: c, key: .marginRight)
        marginHorizontal = Value.yamlDecode(from: c, key: .marginHorizontal)
        marginVertical = Value.yamlDecode(from: c, key: .marginVertical)
        borderRadius = Value.yamlDecode(from: c, key: .borderRadius)
        borderWidth = Value.yamlDecode(from: c, key: .borderWidth)
        borderColor = try c.decodeIfPresent(Value<String>.self, forKey: .borderColor)
        width = Value.yamlDecodeSize(from: c, key: .width)
        height = Value.yamlDecodeSize(from: c, key: .height)
        minWidth = Value.yamlDecodeSize(from: c, key: .minWidth)
        minHeight = Value.yamlDecodeSize(from: c, key: .minHeight)
        maxWidth = Value.yamlDecodeSize(from: c, key: .maxWidth)
        maxHeight = Value.yamlDecodeSize(from: c, key: .maxHeight)
        spacing = Value.yamlDecode(from: c, key: .spacing)
        alignment = try c.decodeIfPresent(Value<ViewAlignment>.self, forKey: .alignment)
        shadow = try c.decodeIfPresent(ShadowStyle.self, forKey: .shadow)
        opacity = Value.yamlDecode(from: c, key: .opacity)
        cornerRadius = Value.yamlDecode(from: c, key: .cornerRadius)
        scale = Value.yamlDecode(from: c, key: .scale)
        rotation = Value.yamlDecode(from: c, key: .rotation)
        animation = try c.decodeIfPresent(String.self, forKey: .animation)
        aspectRatio = Value.yamlDecode(from: c, key: .aspectRatio)
        contentMode = try c.decodeIfPresent(String.self, forKey: .contentMode)
        overflow = try c.decodeIfPresent(String.self, forKey: .overflow)
        lineLimit = Value.yamlDecode(from: c, key: .lineLimit)
        layoutPriority = Value.yamlDecode(from: c, key: .layoutPriority)
    }
}
