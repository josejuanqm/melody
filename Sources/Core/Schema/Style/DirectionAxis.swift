import Foundation

/// Layout axis for stack-based containers.
public enum DirectionAxis: String, Codable, Sendable, Equatable, Hashable {
    case horizontal
    case vertical
    case stacked

    public init(rawValue: String) {
        switch rawValue {
        case "horizontal": self = .horizontal
        case "vertical": self = .vertical
        case "stacked", "z": self = .stacked
        default: self = .vertical
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self.init(rawValue: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
