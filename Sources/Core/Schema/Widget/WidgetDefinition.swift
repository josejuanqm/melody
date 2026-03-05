import Foundation

/// Size family for widget layouts
public enum WidgetFamily: String, Codable, Sendable, Equatable, Hashable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = WidgetFamily(rawValue: raw) ?? WidgetFamily.caseInsensitive(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown widget family: \(raw)"
            )
        }
        self = value
    }

    private static func caseInsensitive(_ string: String) -> WidgetFamily? {
        let lower = string.lowercased()
        switch lower {
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        default: return nil
        }
    }
}

/// HTTP fetch configuration for widget data
public struct WidgetDataFetchDefinition: Codable, Sendable, Equatable, Hashable {
    public var url: String
    public var method: String?
    public var headers: [String: String]?
    public var body: String?
    public var responseType: String?

    public init(url: String, method: String? = nil, headers: [String: String]? = nil, body: String? = nil, responseType: String? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.responseType = responseType
    }
}

/// Data sources for widget rendering
public struct WidgetDataDefinition: Codable, Sendable, Equatable, Hashable {
    public var store: [String]
    public var fetch: WidgetDataFetchDefinition?
    public var prepare: String?

    public init(store: [String] = [], fetch: WidgetDataFetchDefinition? = nil, prepare: String? = nil) {
        self.store = store
        self.fetch = fetch
        self.prepare = prepare
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.store = try container.decodeIfPresent([String].self, forKey: .store) ?? []
        self.fetch = try container.decodeIfPresent(WidgetDataFetchDefinition.self, forKey: .fetch)
        self.prepare = try container.decodeIfPresent(String.self, forKey: .prepare)
    }
}

/// Refresh configuration for widget timeline
public struct WidgetRefreshMode: Codable, Sendable, Equatable, Hashable {
    public var interval: Int?
    public var requiresNetwork: Bool?

    public init(interval: Int? = nil, requiresNetwork: Bool? = nil) {
        self.interval = interval
        self.requiresNetwork = requiresNetwork
    }
}

/// Layout definition for a specific widget family size
public struct WidgetLayout: Codable, Sendable, Equatable, Hashable {
    public var background: Value<String>?
    public var body: [ComponentDefinition]

    public init(background: Value<String>? = nil, body: [ComponentDefinition]) {
        self.background = background
        self.body = body
    }
}

/// A declarative parameter for native widget configuration (AppIntent on iOS, Compose picker on Android).
public struct WidgetParameterDefinition: Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var title: String
    public var type: String
    public var dependsOn: [String]?
    public var query: String

    public init(id: String, title: String, type: String = "entity", dependsOn: [String]? = nil, query: String) {
        self.id = id
        self.title = title
        self.type = type
        self.dependsOn = dependsOn
        self.query = query
    }
}

/// Configuration definition for configurable widgets using native parameter pickers.
public struct WidgetConfigureDefinition: Codable, Sendable, Equatable, Hashable {
    public var title: String?
    public var parameters: [WidgetParameterDefinition]
    public var resolve: String?

    public init(
        title: String? = nil,
        parameters: [WidgetParameterDefinition] = [],
        resolve: String? = nil
    ) {
        self.title = title
        self.parameters = parameters
        self.resolve = resolve
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.parameters = try container.decodeIfPresent([WidgetParameterDefinition].self, forKey: .parameters) ?? []
        self.resolve = try container.decodeIfPresent(String.self, forKey: .resolve)
    }
}

/// Complete widget definition parsed from *.widget.yaml
public struct WidgetDefinition: Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var name: String?
    public var description: String?
    public var families: [WidgetFamily]
    public var link: String?
    public var data: WidgetDataDefinition?
    public var refresh: WidgetRefreshMode?
    public var configure: WidgetConfigureDefinition?
    public var layouts: [WidgetFamily: WidgetLayout]?

    public init(
        id: String,
        name: String? = nil,
        description: String? = nil,
        families: [WidgetFamily] = [],
        link: String? = nil,
        data: WidgetDataDefinition? = nil,
        refresh: WidgetRefreshMode? = nil,
        configure: WidgetConfigureDefinition? = nil,
        layouts: [WidgetFamily: WidgetLayout]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.families = families
        self.link = link
        self.data = data
        self.refresh = refresh
        self.configure = configure
        self.layouts = layouts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.families = try container.decodeIfPresent([WidgetFamily].self, forKey: .families) ?? []
        self.link = try container.decodeIfPresent(String.self, forKey: .link)
        self.data = try container.decodeIfPresent(WidgetDataDefinition.self, forKey: .data)
        self.refresh = try container.decodeIfPresent(WidgetRefreshMode.self, forKey: .refresh)
        self.configure = try container.decodeIfPresent(WidgetConfigureDefinition.self, forKey: .configure)

        if let stringKeyed = try container.decodeIfPresent([String: WidgetLayout].self, forKey: .layouts) {
            var result: [WidgetFamily: WidgetLayout] = [:]
            for (key, value) in stringKeyed {
                let lower = key.lowercased()
                let family: WidgetFamily
                switch lower {
                case "small": family = .small
                case "medium": family = .medium
                case "large": family = .large
                default: continue
                }
                result[family] = value
            }
            self.layouts = result
        } else {
            self.layouts = nil
        }
    }
}
