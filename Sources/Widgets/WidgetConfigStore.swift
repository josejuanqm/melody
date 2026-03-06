import Foundation

/// Per-widget-instance configuration stored in shared UserDefaults (App Groups).
public struct WidgetConfigStore {

    private static let configPrefix = "melody.widget.config."

    public static func saveData(widgetId: String, data: [String: String], suiteName: String) {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
            defaults.set(jsonData, forKey: configPrefix + widgetId)
        }
    }

    public static func getData(widgetId: String, suiteName: String) -> [String: String]? {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        guard let rawData = defaults.data(forKey: configPrefix + widgetId),
              let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: String] else {
            return nil
        }
        return json
    }

    public static func deleteConfig(widgetId: String, suiteName: String) {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removeObject(forKey: configPrefix + widgetId)
    }
}
