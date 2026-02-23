import Foundation

/// Resolved literal or expression-bound property value used in component definitions.
public enum Value<T: Codable & Sendable & Equatable & Hashable>: Sendable, Equatable, Hashable {
    case literal(T)
    case expression(String)

    public var literalValue: T? {
        if case .literal(let v) = self { return v }
        return nil
    }

    public var expressionValue: String? {
        if case .expression(let e) = self { return e }
        return nil
    }

    public static func extractExpression(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{{"), trimmed.hasSuffix("}}") else { return nil }
        return String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Codable

extension Value: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if T.self == String.self {
            let str = try container.decode(String.self)
            if let expr = Self.extractExpression(str) {
                self = .expression(expr)
            } else {
                self = .literal(str as! T)
            }
            return
        }

        if let value = try? container.decode(T.self) {
            self = .literal(value)
            return
        }

        // Yams may present integers as a distinct scalar type
        if T.self == Double.self, let intVal = try? container.decode(Int.self) {
            self = .literal(Double(intVal) as! T)
            return
        }

        let str = try container.decode(String.self)
        if let expr = Self.extractExpression(str) {
            self = .expression(expr)
        } else if T.self == Double.self, let n = Double(str) {
            self = .literal(n as! T)
        } else if T.self == Int.self, let n = Int(str) {
            self = .literal(n as! T)
        } else if T.self == Bool.self {
            switch str.lowercased() {
            case "true", "yes", "1": self = .literal(true as! T)
            case "false", "no", "0": self = .literal(false as! T)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode Value<\(T.self)>: '\(str)' is not a valid literal or {{ expression }}"
                )
            }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode Value<\(T.self)>: '\(str)' is not a valid literal or {{ expression }}"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .literal(let value):
            try container.encode(value)
        case .expression(let expr):
            try container.encode("{{ \(expr) }}")
        }
    }
}

// MARK: - Hashable

extension Value {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .literal(let v):
            hasher.combine(0)
            hasher.combine(v)
        case .expression(let e):
            hasher.combine(1)
            hasher.combine(e)
        }
    }
}

// MARK: - ExpressibleBy*Literal

extension Value: ExpressibleByUnicodeScalarLiteral where T == String {
    public init(unicodeScalarLiteral value: String) {
        self = .literal(value)
    }
}

extension Value: ExpressibleByExtendedGraphemeClusterLiteral where T == String {
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .literal(value)
    }
}

extension Value: ExpressibleByStringLiteral where T == String {
    public init(stringLiteral value: String) {
        self = .literal(value)
    }
}

extension Value: ExpressibleByFloatLiteral where T == Double {
    public init(floatLiteral value: Double) {
        self = .literal(value)
    }
}

extension Value: ExpressibleByIntegerLiteral where T == Int {
    public init(integerLiteral value: Int) {
        self = .literal(value)
    }
}

extension Value: ExpressibleByBooleanLiteral where T == Bool {
    public init(booleanLiteral value: Bool) {
        self = .literal(value)
    }
}

// MARK: - Factory for Lua table → Value conversion

extension Value where T == String {
    public static func from(_ string: String) -> Value<String> {
        if let expr = extractExpression(string) {
            return .expression(expr)
        }
        return .literal(string)
    }
}

extension Value where T == Double {
    public static func from(_ string: String) -> Value<Double>? {
        if let expr = extractExpression(string) {
            return .expression(expr)
        }
        if string.lowercased() == "full" {
            return .literal(-1)
        }
        if let n = Double(string) {
            return .literal(n)
        }
        return nil
    }
}

// MARK: - Convenience for Optional<Value<Double>>

extension Optional where Wrapped == Value<Double> {
    public var resolved: Double? { self?.literalValue }
}

extension Optional where Wrapped == Value<String> {
    public var resolved: String? { self?.literalValue }
}

extension Optional where Wrapped == Value<Int> {
    public var resolved: Int? { self?.literalValue }
}

// MARK: - YAML Decoding Helpers

extension Value where T == Double {
    /// Decodes from a keyed container, handling Yams scalar type coercion
    /// (integers may fail `decode(Double.self)`).
    public static func yamlDecode<K: CodingKey>(from c: KeyedDecodingContainer<K>, key: K) -> Value<Double>? {
        guard c.contains(key) else { return nil }
        if let v = try? c.decode(Value<Double>.self, forKey: key) { return v }
        if let n = try? c.decode(Double.self, forKey: key) { return .literal(n) }
        if let n = try? c.decode(Int.self, forKey: key) { return .literal(Double(n)) }
        if let s = try? c.decode(String.self, forKey: key) {
            if let expr = extractExpression(s) { return .expression(expr) }
            if let n = Double(s) { return .literal(n) }
        }
        return nil
    }

    /// Decodes a size value: number, `"full"` (mapped to `-1`), or `{{ expression }}`.
    public static func yamlDecodeSize<K: CodingKey>(from c: KeyedDecodingContainer<K>, key: K) -> Value<Double>? {
        if let v = yamlDecode(from: c, key: key) { return v }
        if let str = try? c.decode(String.self, forKey: key),
           str.lowercased() == "full" {
            return .literal(-1)
        }
        return nil
    }

    /// Decodes a raw `Double` from a keyed container, coercing integers.
    public static func yamlDecodeRaw<K: CodingKey>(from c: KeyedDecodingContainer<K>, key: K) -> Double? {
        if let n = try? c.decode(Double.self, forKey: key) { return n }
        if let n = try? c.decode(Int.self, forKey: key) { return Double(n) }
        return nil
    }
}

extension Value where T == Bool {
    /// Decodes from a keyed container, handling Yams string representations
    /// (`"true"`, `"yes"`, `"false"`, `"no"`).
    public static func yamlDecode<K: CodingKey>(from c: KeyedDecodingContainer<K>, key: K) -> Value<Bool>? {
        guard c.contains(key) else { return nil }
        if let v = try? c.decode(Value<Bool>.self, forKey: key) { return v }
        if let b = try? c.decode(Bool.self, forKey: key) { return .literal(b) }
        if let s = try? c.decode(String.self, forKey: key) {
            if let expr = extractExpression(s) { return .expression(expr) }
            switch s.lowercased() {
            case "true", "yes": return .literal(true)
            case "false", "no": return .literal(false)
            default: break
            }
        }
        return nil
    }
}

extension Value where T == Int {
    /// Decodes from a keyed container, coercing doubles to integers.
    public static func yamlDecode<K: CodingKey>(from c: KeyedDecodingContainer<K>, key: K) -> Value<Int>? {
        guard c.contains(key) else { return nil }
        if let v = try? c.decode(Value<Int>.self, forKey: key) { return v }
        if let n = try? c.decode(Int.self, forKey: key) { return .literal(n) }
        if let n = try? c.decode(Double.self, forKey: key) { return .literal(Int(n)) }
        if let s = try? c.decode(String.self, forKey: key) {
            if let expr = extractExpression(s) { return .expression(expr) }
            if let n = Int(s) { return .literal(n) }
        }
        return nil
    }
}
