import Foundation
import Core

/// Resolves widget data from shared UserDefaults, per-instance config, and optional HTTP fetch.
public struct WidgetDataProvider {

    public static func resolve(
        widget: WidgetDefinition,
        widgetId: String? = nil,
        suiteName: String
    ) async -> [String: String] {
        var data: [String: String] = [:]
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let prefix = "melody.store.\(Bundle.main.bundleIdentifier ?? "")-"

        if let widgetData = widget.data {
            for key in widgetData.store {
                if let rawData = defaults.data(forKey: prefix + key),
                   let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
                   let inner = json["v"] {
                    data[key] = stringFromJSON(inner)
                }
            }
        }

        if let widgetId {
            let configData = WidgetConfigStore.getData(widgetId: widgetId, suiteName: suiteName)
            if let configData {
                for (key, value) in configData {
                    data[key] = value
                }
            }
        }

        if let fetch = widget.data?.fetch {
            let resolvedUrl = resolveStoreRefs(fetch.url, data: data)
            let resolvedHeaders = fetch.headers?.mapValues { resolveStoreRefs($0, data: data) }
            if let response = await httpGet(url: resolvedUrl, headers: resolvedHeaders) {
                flattenJSON(response, prefix: "", into: &data)
            }
        }

        return data
    }

    private static func resolveStoreRefs(_ value: String, data: [String: String]) -> String {
        let pattern = try! NSRegularExpression(pattern: #"\{\{\s*data\.([\w.]+)\s*\}\}"#)
        let range = NSRange(value.startIndex..., in: value)
        var result = value
        for match in pattern.matches(in: value, range: range).reversed() {
            guard let keyRange = Range(match.range(at: 1), in: value) else { continue }
            let key = String(value[keyRange])
            let replacement = data[key] ?? ""
            guard let fullRange = Range(match.range, in: result) else { continue }
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }

    private static func httpGet(url urlString: String, headers: [String: String]?) async -> Any? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return json
    }

    private static func flattenJSON(_ json: Any, prefix: String, into data: inout [String: String]) {
        if let dict = json as? [String: Any] {
            for (key, value) in dict {
                let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
                if value is [String: Any] || value is [Any] {
                    flattenJSON(value, prefix: fullKey, into: &data)
                } else {
                    data[fullKey] = stringFromJSON(value)
                }
            }
        } else if let array = json as? [Any] {
            for (index, value) in array.enumerated() {
                let fullKey = "\(prefix).\(index)"
                flattenJSON(value, prefix: fullKey, into: &data)
            }
        } else {
            data[prefix] = stringFromJSON(json)
        }
    }

    private static func stringFromJSON(_ value: Any) -> String {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        if value is NSNull { return "" }
        return "\(value)"
    }
}
