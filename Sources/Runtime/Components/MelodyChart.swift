import SwiftUI
import Charts
import Core

/// A data point extracted from Lua tables for chart rendering
struct ChartDataPoint: Identifiable {
    let id: Int
    let values: [String: ChartValue]

    func string(for key: String) -> String {
        values[key]?.stringValue ?? ""
    }

    func number(for key: String) -> Double {
        values[key]?.numberValue ?? 0
    }
}

/// A value in a chart data point — either numeric or textual
enum ChartValue {
    case number(Double)
    case text(String)

    var stringValue: String {
        switch self {
        case .number(let n):
            if n == n.rounded() && n < 1e15 { return String(Int(n)) }
            return String(n)
        case .text(let s): return s
        }
    }

    var numberValue: Double {
        switch self {
        case .number(let n): return n
        case .text(_): return 0
        }
    }
}

/// Resolves an interpolation method string to Swift Charts InterpolationMethod
private func resolveInterpolation(_ value: String?) -> InterpolationMethod {
    switch ChartInterpolation(value) {
    case .linear: return .linear
    case .catmullRom: return .catmullRom
    case .cardinal: return .cardinal
    case .monotone: return .monotone
    case .stepStart: return .stepStart
    case .stepCenter: return .stepCenter
    case .stepEnd: return .stepEnd
    }
}

/// Renders a Swift Charts view from a ``ComponentDefinition`` with configurable mark types.
struct MelodyChart: View {
    let definition: ComponentDefinition
    let resolvedItems: [LuaValue]

    @Environment(\.themeColors) private var themeColors

    var body: some View {
        let dataPoints = extractDataPoints()
        let marks = definition.marks ?? []

        chartView(dataPoints: dataPoints, marks: marks)
            .melodyStyle(definition.style)
    }

    @ViewBuilder
    private func chartView(dataPoints: [ChartDataPoint], marks: [MarkDefinition]) -> some View {
        let hasSector = marks.contains { ChartMarkType($0.type) == .sector }

        if hasSector {
            if let sectorMark = marks.first(where: { ChartMarkType($0.type) == .sector }) {
                sectorChart(dataPoints: dataPoints, mark: sectorMark)
            }
        } else {
            cartesianChart(dataPoints: dataPoints, marks: marks)
        }
    }

    // MARK: - Cartesian Chart

    @ViewBuilder
    private func cartesianChart(dataPoints: [ChartDataPoint], marks: [MarkDefinition]) -> some View {
        Chart {
            ForEach(marks, id: \.type) { mark in
                switch ChartMarkType(mark.type) {
                case .bar:
                    renderBarMarks(dataPoints: dataPoints, mark: mark)
                case .line:
                    renderLineMarks(dataPoints: dataPoints, mark: mark)
                case .point:
                    renderPointMarks(dataPoints: dataPoints, mark: mark)
                case .area:
                    renderAreaMarks(dataPoints: dataPoints, mark: mark)
                case .rule:
                    renderRuleMark(mark: mark)
                case .rectangle:
                    renderRectangleMarks(dataPoints: dataPoints, mark: mark)
                case .sector:
                    renderBarMarks(dataPoints: dataPoints, mark: mark)
                }
            }
        }
        .applyChartXAxis(hidden: definition.hideXAxis == true)
        .applyChartYAxis(hidden: definition.hideYAxis == true)
        .applyChartLegend(position: definition.legendPosition)
        .applyChartColorScale(colors: resolveColors())
    }

    // MARK: - Sector Chart

    @ViewBuilder
    private func sectorChart(dataPoints: [ChartDataPoint], mark: MarkDefinition) -> some View {
        let angleKey = mark.angleKey ?? "value"
        let groupKey = mark.groupKey
        let cr = CGFloat(mark.cornerRadius ?? 0)

        Chart(dataPoints) { point in
            let angle = point.number(for: angleKey)

            if let groupKey, !groupKey.isEmpty {
                SectorMark(
                    angle: .value(angleKey, angle),
                    innerRadius: sectorInnerRadius(mark),
                    angularInset: mark.angularInset ?? 0
                )
                .foregroundStyle(by: .value(groupKey, point.string(for: groupKey)))
                .cornerRadius(cr)
            } else {
                SectorMark(
                    angle: .value(angleKey, angle),
                    innerRadius: sectorInnerRadius(mark),
                    angularInset: mark.angularInset ?? 0
                )
                .cornerRadius(cr)
            }
        }
        .applyChartLegend(position: definition.legendPosition)
        .applyChartColorScale(colors: resolveColors())
    }

    private func sectorInnerRadius(_ mark: MarkDefinition) -> MarkDimension {
        if let ratio = mark.innerRadius {
            return .ratio(ratio)
        }
        return .ratio(0)
    }

    // MARK: - Bar Mark

    @ChartContentBuilder
    private func renderBarMarks(dataPoints: [ChartDataPoint], mark: MarkDefinition) -> some ChartContent {
        let xKey = mark.xKey ?? "x"
        let yKey = mark.yKey ?? "y"
        let cr = CGFloat(mark.cornerRadius ?? 0)

        ForEach(dataPoints) { point in
            let x = point.string(for: xKey)
            let y = point.number(for: yKey)

            if let groupKey = mark.groupKey, !groupKey.isEmpty {
                BarMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(by: .value(groupKey, point.string(for: groupKey)))
                .cornerRadius(cr)
            } else {
                BarMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(resolveMarkColor(mark.color))
                .cornerRadius(cr)
            }
        }
    }

    // MARK: - Line Mark

    @ChartContentBuilder
    private func renderLineMarks(dataPoints: [ChartDataPoint], mark: MarkDefinition) -> some ChartContent {
        let xKey = mark.xKey ?? "x"
        let yKey = mark.yKey ?? "y"
        let interp = resolveInterpolation(mark.interpolation)
        let lineStyle = StrokeStyle(lineWidth: mark.lineWidth ?? 2)

        ForEach(dataPoints) { point in
            let x = point.string(for: xKey)
            let y = point.number(for: yKey)

            if let groupKey = mark.groupKey, !groupKey.isEmpty {
                LineMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(by: .value(groupKey, point.string(for: groupKey)))
                .interpolationMethod(interp)
                .lineStyle(lineStyle)
            } else {
                LineMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(resolveMarkColor(mark.color))
                .interpolationMethod(interp)
                .lineStyle(lineStyle)
            }
        }
    }

    // MARK: - Point Mark

    @ChartContentBuilder
    private func renderPointMarks(dataPoints: [ChartDataPoint], mark: MarkDefinition) -> some ChartContent {
        let xKey = mark.xKey ?? "x"
        let yKey = mark.yKey ?? "y"
        let size = mark.symbolSize ?? 64

        ForEach(dataPoints) { point in
            let x = point.string(for: xKey)
            let y = point.number(for: yKey)

            if let groupKey = mark.groupKey, !groupKey.isEmpty {
                PointMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(by: .value(groupKey, point.string(for: groupKey)))
                .symbolSize(size)
            } else {
                PointMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(resolveMarkColor(mark.color))
                .symbolSize(size)
            }
        }
    }

    // MARK: - Area Mark

    @ChartContentBuilder
    private func renderAreaMarks(dataPoints: [ChartDataPoint], mark: MarkDefinition) -> some ChartContent {
        let xKey = mark.xKey ?? "x"
        let yKey = mark.yKey ?? "y"
        let interp = resolveInterpolation(mark.interpolation)

        ForEach(dataPoints) { point in
            let x = point.string(for: xKey)
            let y = point.number(for: yKey)

            if let groupKey = mark.groupKey, !groupKey.isEmpty {
                AreaMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(by: .value(groupKey, point.string(for: groupKey)))
                .interpolationMethod(interp)
            } else {
                AreaMark(
                    x: .value(xKey, x),
                    y: .value(yKey, y)
                )
                .foregroundStyle(resolveMarkColor(mark.color))
                .interpolationMethod(interp)
            }
        }
    }

    // MARK: - Rule Mark

    @ChartContentBuilder
    private func renderRuleMark(mark: MarkDefinition) -> some ChartContent {
        let ruleColor = resolveMarkColor(mark.color ?? "#FF3B30")
        let lineStyle = StrokeStyle(lineWidth: mark.lineWidth ?? 1)

        if let yVal = mark.yValue {
            if let labelText = mark.label {
                RuleMark(y: .value("threshold", yVal))
                    .foregroundStyle(ruleColor)
                    .lineStyle(lineStyle)
                    .annotation(position: .top, alignment: .leading) {
                        Text(labelText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            } else {
                RuleMark(y: .value("threshold", yVal))
                    .foregroundStyle(ruleColor)
                    .lineStyle(lineStyle)
            }
        } else if let xVal = mark.xValue {
            if let labelText = mark.label {
                RuleMark(x: .value("threshold", xVal))
                    .foregroundStyle(ruleColor)
                    .lineStyle(lineStyle)
                    .annotation(position: .top, alignment: .leading) {
                        Text(labelText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            } else {
                RuleMark(x: .value("threshold", xVal))
                    .foregroundStyle(ruleColor)
                    .lineStyle(lineStyle)
            }
        }
    }

    // MARK: - Rectangle Mark

    @ChartContentBuilder
    private func renderRectangleMarks(dataPoints: [ChartDataPoint], mark: MarkDefinition) -> some ChartContent {
        let xStartKey = mark.xStartKey ?? mark.xKey ?? "xStart"
        let xEndKey = mark.xEndKey ?? "xEnd"
        let yStartKey = mark.yStartKey ?? mark.yKey ?? "yStart"
        let yEndKey = mark.yEndKey ?? "yEnd"

        ForEach(dataPoints) { point in
            let xStart = point.string(for: xStartKey)
            let xEnd = point.string(for: xEndKey)
            let yStart = point.number(for: yStartKey)
            let yEnd = point.number(for: yEndKey)

            if let groupKey = mark.groupKey, !groupKey.isEmpty {
                RectangleMark(
                    xStart: .value("xStart", xStart),
                    xEnd: .value("xEnd", xEnd),
                    yStart: .value("yStart", yStart),
                    yEnd: .value("yEnd", yEnd)
                )
                .foregroundStyle(by: .value(groupKey, point.string(for: groupKey)))
            } else {
                RectangleMark(
                    xStart: .value("xStart", xStart),
                    xEnd: .value("xEnd", xEnd),
                    yStart: .value("yStart", yStart),
                    yEnd: .value("yEnd", yEnd)
                )
                .foregroundStyle(resolveMarkColor(mark.color))
            }
        }
    }

    // MARK: - Data Extraction

    private func extractDataPoints() -> [ChartDataPoint] {
        let marks = definition.marks ?? []
        var allKeys = Set<String>()

        for mark in marks {
            if let k = mark.xKey { allKeys.insert(k) }
            if let k = mark.yKey { allKeys.insert(k) }
            if let k = mark.groupKey { allKeys.insert(k) }
            if let k = mark.angleKey { allKeys.insert(k) }
            if let k = mark.xStartKey { allKeys.insert(k) }
            if let k = mark.xEndKey { allKeys.insert(k) }
            if let k = mark.yStartKey { allKeys.insert(k) }
            if let k = mark.yEndKey { allKeys.insert(k) }
        }

        return resolvedItems.enumerated().compactMap { index, item in
            guard let table = item.tableValue else { return nil }
            var values: [String: ChartValue] = [:]
            for key in allKeys {
                if let luaVal = table[key] {
                    switch luaVal {
                    case .number(let n):
                        values[key] = .number(n)
                    case .string(let s):
                        if let n = Double(s) {
                            values[key] = .number(n)
                        } else {
                            values[key] = .text(s)
                        }
                    case .bool(let b):
                        values[key] = .text(b ? "true" : "false")
                    default:
                        values[key] = .text(String(describing: luaVal))
                    }
                }
            }
            return ChartDataPoint(id: index, values: values)
        }
    }

    // MARK: - Color Resolution

    private func resolveMarkColor(_ colorString: String?) -> Color {
        guard let colorString else { return .blue }
        return Color(hex: StyleResolver.colorHex(colorString, themeColors: themeColors))
    }

    private func resolveColors() -> [Color]? {
        guard let colorStrings = definition.colors, !colorStrings.isEmpty else { return nil }
        return colorStrings.map { Color(hex: StyleResolver.colorHex($0, themeColors: themeColors)) }
    }
}

// MARK: - Chart View Modifier Extensions

extension View {
    @ViewBuilder
    func applyChartXAxis(hidden: Bool) -> some View {
        if hidden {
            self.chartXAxis(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyChartYAxis(hidden: Bool) -> some View {
        if hidden {
            self.chartYAxis(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyChartLegend(position: String?) -> some View {
        switch ChartLegendPosition(position) {
        case .hidden:
            self.chartLegend(.hidden)
        case .bottom:
            self.chartLegend(position: .bottom)
        case .top:
            self.chartLegend(position: .top)
        case .leading:
            self.chartLegend(position: .leading)
        case .trailing:
            self.chartLegend(position: .trailing)
        case .automatic:
            self.chartLegend(position: .automatic)
        }
    }

    @ViewBuilder
    func applyChartColorScale(colors: [Color]?) -> some View {
        if let colors, !colors.isEmpty {
            self.chartForegroundStyleScale(range: colors)
        } else {
            self
        }
    }
}
