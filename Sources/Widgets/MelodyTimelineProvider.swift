#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
import Core
import Yams

/// Timeline entry holding resolved widget data for a snapshot in time.
public struct MelodyWidgetEntry: TimelineEntry {
    public let date: Date
    public let widgetDefinition: WidgetDefinition
    public let data: [String: String]
    public let themeColors: [String: String]
    public let family: Core.WidgetFamily
    /// The config entity ID for this widget instance (nil for static/unconfigured widgets).
    public let configEntityId: String?

    public init(date: Date, widgetDefinition: WidgetDefinition, data: [String: String], themeColors: [String: String], family: Core.WidgetFamily, configEntityId: String? = nil) {
        self.date = date
        self.widgetDefinition = widgetDefinition
        self.data = data
        self.themeColors = themeColors
        self.family = family
        self.configEntityId = configEntityId
    }
}

/// Generic TimelineProvider that parses embedded widget YAML and resolves data.
public struct MelodyTimelineProvider: TimelineProvider {

    let widgetYAML: String
    let suiteName: String

    public init(widgetYAML: String, suiteName: String) {
        self.widgetYAML = widgetYAML
        self.suiteName = suiteName
    }

    public func placeholder(in context: Context) -> MelodyWidgetEntry {
        let definition = parseDefinition()
        let family = mapFamily(context.family)
        return MelodyWidgetEntry(
            date: Date.now,
            widgetDefinition: definition,
            data: [:],
            themeColors: loadThemeColors(),
            family: family
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (MelodyWidgetEntry) -> Void) {
        let definition = parseDefinition()
        let family = mapFamily(context.family)
        let suite = suiteName
        let colors = loadThemeColors()
        Task {
            let data = await WidgetDataProvider.resolve(
                widget: definition,
                suiteName: suite
            )
            let entry = MelodyWidgetEntry(
                date: Date.now,
                widgetDefinition: definition,
                data: data,
                themeColors: colors,
                family: family
            )
            completion(entry)
        }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<MelodyWidgetEntry>) -> Void) {
        let definition = parseDefinition()
        let family = mapFamily(context.family)
        let suite = suiteName
        let colors = loadThemeColors()
        Task {
            let data = await WidgetDataProvider.resolve(
                widget: definition,
                suiteName: suite
            )
            let entry = MelodyWidgetEntry(
                date: Date.now,
                widgetDefinition: definition,
                data: data,
                themeColors: colors,
                family: family
            )
            let intervalMinutes = definition.refresh?.interval ?? 30
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: intervalMinutes, to: Date.now) ?? Date.now.addingTimeInterval(1800)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func parseDefinition() -> WidgetDefinition {
        let decoder = YAMLDecoder()
        return (try? decoder.decode(WidgetDefinition.self, from: widgetYAML))
            ?? WidgetDefinition(id: "unknown")
    }

    private func mapFamily(_ family: WidgetKit.WidgetFamily) -> Core.WidgetFamily {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemLarge: return .large
        default: return .small
        }
    }

    private func loadThemeColors() -> [String: String] {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        guard let data = defaults.data(forKey: "melody.theme.colors"),
              let colors = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return colors
    }
}
#endif
