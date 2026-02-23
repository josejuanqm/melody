import Foundation

/// Named alignment position for content within a container.
public enum ViewAlignment: String, Codable, Sendable, Equatable {
    case center
    case top
    case bottom
    case leading
    case left
    case trailing
    case right
    case topLeading
    case topLeft
    case topTrailing
    case topRight
    case bottomLeading
    case bottomLeft
    case bottomTrailing
    case bottomRight

    public init(rawValue: String) {
        switch rawValue {
        case "center": self = .center
        case "top": self = .top
        case "bottom": self = .bottom
        case "leading": self = .leading
        case "left": self = .left
        case "trailing": self = .trailing
        case "right": self = .right
        case "topLeading": self = .topLeading
        case "topLeft": self = .topLeft
        case "topTrailing": self = .topTrailing
        case "topRight": self = .topRight
        case "bottomLeading": self = .bottomLeading
        case "bottomLeft": self = .bottomLeft
        case "bottomTrailing": self = .bottomTrailing
        case "bottomRight": self = .bottomRight
        default: self = .leading
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
