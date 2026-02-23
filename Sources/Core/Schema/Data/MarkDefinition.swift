import Foundation

/// Defines a single chart mark (bar, line, point, area, rule, rectangle, sector)
public struct MarkDefinition: Codable, Sendable, Equatable, Hashable {
    /// Mark type: "bar", "line", "point", "area", "rule", "rectangle", "sector"
    public var type: String

    public var xKey: String?
    public var yKey: String?

    public var groupKey: String?

    public var angleKey: String?
    public var innerRadius: Double?
    public var angularInset: Double?

    public var xValue: String?
    public var yValue: Double?
    public var label: String?

    public var xStartKey: String?
    public var xEndKey: String?
    public var yStartKey: String?
    public var yEndKey: String?

    public var interpolation: String?

    public var lineWidth: Double?
    public var cornerRadius: Double?
    public var symbolSize: Double?
    public var stacking: String?
    public var color: String?

    public init(
        type: String,
        xKey: String? = nil,
        yKey: String? = nil,
        groupKey: String? = nil,
        angleKey: String? = nil,
        innerRadius: Double? = nil,
        angularInset: Double? = nil,
        xValue: String? = nil,
        yValue: Double? = nil,
        label: String? = nil,
        xStartKey: String? = nil,
        xEndKey: String? = nil,
        yStartKey: String? = nil,
        yEndKey: String? = nil,
        interpolation: String? = nil,
        lineWidth: Double? = nil,
        cornerRadius: Double? = nil,
        symbolSize: Double? = nil,
        stacking: String? = nil,
        color: String? = nil
    ) {
        self.type = type
        self.xKey = xKey
        self.yKey = yKey
        self.groupKey = groupKey
        self.angleKey = angleKey
        self.innerRadius = innerRadius
        self.angularInset = angularInset
        self.xValue = xValue
        self.yValue = yValue
        self.label = label
        self.xStartKey = xStartKey
        self.xEndKey = xEndKey
        self.yStartKey = yStartKey
        self.yEndKey = yEndKey
        self.interpolation = interpolation
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        self.symbolSize = symbolSize
        self.stacking = stacking
        self.color = color
    }
}
