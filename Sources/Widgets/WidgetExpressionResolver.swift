import Foundation
import Core

/// Single-pass resolver that walks a component tree and replaces
/// `{{ data.xxx }}` expressions with literal values from the data map.
public struct WidgetExpressionResolver {

    public static func resolve(
        components: [ComponentDefinition],
        data: [String: String]
    ) -> [ComponentDefinition] {
        return components.compactMap { comp in
            let resolved = resolveComponent(comp, data: data)
            if case .literal(false) = resolved.visible {
                return nil
            }
            return resolved
        }
    }

    public static func resolveValue(_ value: Value<String>?, data: [String: String]) -> String? {
        guard let value else { return nil }
        switch value {
        case .literal(let str):
            return resolveExpressionString(str, data: data)
        case .expression(let expr):
            return resolveExpressionString(expr, data: data)
        }
    }

    private static func resolveComponent(_ def: ComponentDefinition, data: [String: String]) -> ComponentDefinition {
        var resolved = def
        resolved.text = resolveStringValue(def.text, data: data)
        resolved.label = resolveStringValue(def.label, data: data)
        resolved.src = resolveStringValue(def.src, data: data)
        resolved.value = resolveStringValue(def.value, data: data)
        resolved.systemImage = resolveStringValue(def.systemImage, data: data)
        resolved.url = resolveStringValue(def.url, data: data)
        resolved.placeholder = resolveStringValue(def.placeholder, data: data)
        resolved.visible = resolveBoolValue(def.visible, data: data)
        resolved.style = resolveStyle(def.style, data: data)
        resolved.children = def.children.map { resolve(components: $0, data: data) }
        return resolved
    }

    private static func resolveStringValue(_ value: Value<String>?, data: [String: String]) -> Value<String>? {
        guard let value else { return nil }
        switch value {
        case .literal(let str):
            return .literal(resolveExpressionString(str, data: data))
        case .expression(let expr):
            return .literal(resolveExpressionString(expr, data: data))
        }
    }

    private static func resolveBoolValue(_ value: Value<Bool>?, data: [String: String]) -> Value<Bool>? {
        guard let value else { return nil }
        switch value {
        case .literal:
            return value
        case .expression(let expr):
            return .literal(evaluateBoolExpression(expr, data: data))
        }
    }

    /// Evaluates common Lua-style boolean expressions against the data map.
    /// Supports patterns like:
    ///   - `data.X` → truthy (non-empty)
    ///   - `data.X and data.Y` → both truthy
    ///   - `data.X and data.X ~= ''` → non-empty check
    ///   - `not data.X` → falsy
    ///   - `data.X == 'value'` → equality
    ///   - `data.X ~= 'value'` → inequality
    private static func evaluateBoolExpression(_ expr: String, data: [String: String]) -> Bool {
        let trimmed = expr.trimmingCharacters(in: .whitespaces)

        // Split on " and " / " or " for compound expressions
        if let andRange = trimmed.range(of: " and ", options: .literal) {
            let left = String(trimmed[trimmed.startIndex..<andRange.lowerBound])
            let right = String(trimmed[andRange.upperBound...])
            return evaluateBoolExpression(left, data: data) && evaluateBoolExpression(right, data: data)
        }
        if let orRange = trimmed.range(of: " or ", options: .literal) {
            let left = String(trimmed[trimmed.startIndex..<orRange.lowerBound])
            let right = String(trimmed[orRange.upperBound...])
            return evaluateBoolExpression(left, data: data) || evaluateBoolExpression(right, data: data)
        }

        // "not data.X"
        if trimmed.hasPrefix("not ") {
            let inner = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            return !evaluateBoolExpression(inner, data: data)
        }

        // "data.X ~= 'value'" or "data.X ~= ''"
        if let match = trimmed.range(of: #"data\.(\w+)\s*~=\s*'([^']*)'"#, options: .regularExpression) {
            let sub = String(trimmed[match])
            let regex = try! NSRegularExpression(pattern: #"data\.(\w+)\s*~=\s*'([^']*)'"#)
            let nsRange = NSRange(sub.startIndex..., in: sub)
            if let m = regex.firstMatch(in: sub, range: nsRange),
               let keyRange = Range(m.range(at: 1), in: sub),
               let valRange = Range(m.range(at: 2), in: sub) {
                let key = String(sub[keyRange])
                let val = String(sub[valRange])
                return (data[key] ?? "") != val
            }
        }

        // "data.X == 'value'"
        if let match = trimmed.range(of: #"data\.(\w+)\s*==\s*'([^']*)'"#, options: .regularExpression) {
            let sub = String(trimmed[match])
            let regex = try! NSRegularExpression(pattern: #"data\.(\w+)\s*==\s*'([^']*)'"#)
            let nsRange = NSRange(sub.startIndex..., in: sub)
            if let m = regex.firstMatch(in: sub, range: nsRange),
               let keyRange = Range(m.range(at: 1), in: sub),
               let valRange = Range(m.range(at: 2), in: sub) {
                let key = String(sub[keyRange])
                let val = String(sub[valRange])
                return (data[key] ?? "") == val
            }
        }

        // "data.X" — truthy check (exists and non-empty)
        if let match = trimmed.range(of: #"^data\.(\w+)$"#, options: .regularExpression) {
            let key = String(trimmed[match]).replacingOccurrences(of: "data.", with: "")
            let val = data[key] ?? ""
            return !val.isEmpty
        }

        // Fallback: resolve string and check truthiness
        let resolved = resolveExpressionString(trimmed, data: data)
        switch resolved.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no", "": return false
        default: return !resolved.isEmpty
        }
    }

    private static func resolveExpressionString(_ expr: String, data: [String: String]) -> String {
        let pattern = try! NSRegularExpression(pattern: #"\{\{\s*data\.([\w.]+)\s*\}\}"#)
        let range = NSRange(expr.startIndex..., in: expr)
        var result = expr
        for match in pattern.matches(in: expr, range: range).reversed() {
            guard let keyRange = Range(match.range(at: 1), in: expr) else { continue }
            let key = String(expr[keyRange])
            let replacement = data[key] ?? ""
            guard let fullRange = Range(match.range, in: result) else { continue }
            result.replaceSubrange(fullRange, with: replacement)
        }
        let barePattern = try! NSRegularExpression(pattern: #"data\.([\w.]+)"#)
        let bareRange = NSRange(result.startIndex..., in: result)
        for match in barePattern.matches(in: result, range: bareRange).reversed() {
            guard let keyRange = Range(match.range(at: 1), in: result) else { continue }
            let key = String(result[keyRange])
            let replacement = data[key] ?? ""
            guard let fullRange = Range(match.range, in: result) else { continue }
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }

    private static func resolveStyle(_ style: ComponentStyle?, data: [String: String]) -> ComponentStyle? {
        guard var style else { return nil }
        style.color = resolveStringValue(style.color, data: data)
        style.backgroundColor = resolveStringValue(style.backgroundColor, data: data)
        style.borderColor = resolveStringValue(style.borderColor, data: data)
        return style
    }
}
