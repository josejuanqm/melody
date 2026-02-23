import SwiftUI
import Core

/// Extracts Lua expression resolution from component rendering.
/// All typed resolve methods share the same `vm` + `props` dependency pair.
struct ExpressionResolver {
    let vm: LuaVM?
    let props: [String: LuaValue]?
    let state: [String: LuaValue]?

    // MARK: - Internal Helpers

    /// Returns a `local props = { ... }` Lua snippet, or "" if no props.
    func propsPrefix() -> String {
        guard let vm, let props else { return "" }
        return vm.localPrefix(key: "props", for: props)
    }

    /// Returns a `local state = { ... }` Lua snippet, or "" if no props.
    func statePrefix() -> String {
        guard let vm, let state else { return "" }
        return vm.localPrefix(key: "state", for: state)
    }

    /// Evaluate a Lua expression with local props injected.
    func evaluate(_ expression: String) throws -> LuaValue {
        guard let vm else { throw LuaError.initializationFailed }
        let prefix = "\(propsPrefix())\n\(statePrefix())"
        return try vm.execute(prefix + "return " + expression)
    }

    // MARK: - Typed Resolve Methods

    func string(_ value: Value<String>?) -> String {
        guard let value else { return "" }
        switch value {
        case .literal(let s): return s
        case .expression(let expr):
            guard vm != nil else { return "" }
            guard let result = try? evaluate(expr) else { return "" }
            switch result {
            case .string(let s): return s
            case .number(let n):
                if n == n.rounded() && n < 1e15 { return String(Int(n)) }
                return String(n)
            case .bool(let b): return b ? "true" : "false"
            case .nil: return ""
            default: return String(describing: result)
            }
        }
    }

    func number(_ value: Value<Double>?) -> Double? {
        guard let value else { return nil }
        switch value {
        case .literal(let n): return n
        case .expression(let expr):
            return (try? evaluate(expr))?.numberValue
        }
    }

    func integer(_ value: Value<Int>?) -> Int? {
        guard let value else { return nil }
        switch value {
        case .literal(let n): return n
        case .expression(let expr):
            return (try? evaluate(expr))?.numberValue.map(Int.init)
        }
    }

    func bool(_ value: Value<Bool>?, default defaultValue: Bool) -> Bool {
        guard let value, vm != nil else { return defaultValue }
        switch value {
        case .literal(let b): return b
        case .expression(let expr):
            do {
                let result = try evaluate(expr)
                if case .bool(let b) = result { return b }
                return defaultValue
            } catch {
                return defaultValue
            }
        }
    }

    func visible(_ value: Value<Bool>?) -> Bool {
        guard let value else { return true }
        switch value {
        case .literal(let b): return b
        case .expression(let expr):
            guard vm != nil else { return true }
            do {
                let result = try evaluate(expr)
                switch result {
                case .bool(let b): return b
                case .nil: return false
                default: return true
                }
            } catch {
                return true
            }
        }
    }

    func disabled(_ value: Value<Bool>?) -> Bool {
        return bool(value, default: false)
    }

    func items(_ expression: String?) -> [LuaValue] {
        guard let expression, vm != nil else { return [] }
        do {
            let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
            let result: LuaValue
            if trimmed.contains("\n") {
                let prefix = propsPrefix()
                result = try vm!.execute(prefix + expression)
            } else {
                result = try evaluate(expression)
            }
            if case .array(let items) = result {
                return items
            }
            return []
        } catch {
            return []
        }
    }

    func options(_ source: OptionsSource?) -> [OptionDefinition] {
        guard let source else { return [] }
        switch source {
        case .static(let arr):
            return arr
        case .expression(let expr):
            guard vm != nil else { return [] }
            do {
                let result = try evaluate(expr)
                if case .array(let items) = result {
                    return items.compactMap { item in
                        guard let t = item.tableValue,
                              let label = t["label"]?.stringValue,
                              let value = t["value"]?.stringValue else { return nil }
                        return OptionDefinition(label: label, value: value)
                    }
                }
                return []
            } catch {
                return []
            }
        }
    }

    func direction(_ value: Value<DirectionAxis>?, default defaultValue: DirectionAxis = .vertical) -> DirectionAxis {
        guard let value else { return defaultValue }
        switch value {
        case .literal(let dir): return dir
        case .expression(let expr):
            let resolved = string(.expression(expr))
            return DirectionAxis(rawValue: resolved)
        }
    }

    func alignment(_ value: Value<ViewAlignment>?, default defaultValue: ViewAlignment = .leading) -> ViewAlignment {
        guard let value else { return defaultValue }
        switch value {
        case .literal(let a): return a
        case .expression(let expr):
            let resolved = string(.expression(expr))
            return ViewAlignment(rawValue: resolved)
        }
    }

    /// Resolves all `Value` expressions in a style to `.literal` values.
    func style(_ style: ComponentStyle?) -> ComponentStyle? {
        guard var style, vm != nil else { return style }

        // Resolve color strings
        if case .expression = style.color { style.color = resolveStringValue(style.color) }
        if case .expression = style.backgroundColor { style.backgroundColor = resolveStringValue(style.backgroundColor) }
        if case .expression = style.borderColor { style.borderColor = resolveStringValue(style.borderColor) }

        // Resolve alignment
        if case .expression = style.alignment {
            style.alignment = .literal(alignment(style.alignment))
        }

        // Resolve all numeric Value<Double> expressions
        style.fontSize = resolveDoubleValue(style.fontSize)
        style.padding = resolveDoubleValue(style.padding)
        style.paddingTop = resolveDoubleValue(style.paddingTop)
        style.paddingBottom = resolveDoubleValue(style.paddingBottom)
        style.paddingLeft = resolveDoubleValue(style.paddingLeft)
        style.paddingRight = resolveDoubleValue(style.paddingRight)
        style.paddingHorizontal = resolveDoubleValue(style.paddingHorizontal)
        style.paddingVertical = resolveDoubleValue(style.paddingVertical)
        style.margin = resolveDoubleValue(style.margin)
        style.marginTop = resolveDoubleValue(style.marginTop)
        style.marginBottom = resolveDoubleValue(style.marginBottom)
        style.marginLeft = resolveDoubleValue(style.marginLeft)
        style.marginRight = resolveDoubleValue(style.marginRight)
        style.marginHorizontal = resolveDoubleValue(style.marginHorizontal)
        style.marginVertical = resolveDoubleValue(style.marginVertical)
        style.borderRadius = resolveDoubleValue(style.borderRadius)
        style.borderWidth = resolveDoubleValue(style.borderWidth)
        style.width = resolveDoubleValue(style.width)
        style.height = resolveDoubleValue(style.height)
        style.minWidth = resolveDoubleValue(style.minWidth)
        style.minHeight = resolveDoubleValue(style.minHeight)
        style.maxWidth = resolveDoubleValue(style.maxWidth)
        style.maxHeight = resolveDoubleValue(style.maxHeight)
        style.spacing = resolveDoubleValue(style.spacing)
        style.opacity = resolveDoubleValue(style.opacity)
        style.cornerRadius = resolveDoubleValue(style.cornerRadius)
        style.scale = resolveDoubleValue(style.scale)
        style.rotation = resolveDoubleValue(style.rotation)
        style.aspectRatio = resolveDoubleValue(style.aspectRatio)
        style.layoutPriority = resolveDoubleValue(style.layoutPriority)

        // Resolve lineLimit
        if case .expression(let expr) = style.lineLimit {
            if let n = (try? evaluate(expr))?.numberValue {
                style.lineLimit = .literal(Int(n))
            }
        }

        return style
    }

    func transition(_ value: Value<String>?) -> AnyTransition {
        let str = string(value)
        guard !str.isEmpty else { return .opacity }
        let parts = str.lowercased().split(separator: ".")
        var result: AnyTransition? = nil
        var i = 0
        while i < parts.count {
            let t: AnyTransition
            switch parts[i] {
            case "opacity": t = .opacity
            case "slide": t = .slide
            case "scale": t = .scale
            case "move":
                i += 1
                let edge: Edge = i < parts.count ? (parts[i] == "top" ? .top : parts[i] == "leading" ? .leading : parts[i] == "trailing" ? .trailing : .bottom) : .bottom
                t = .move(edge: edge)
            default: t = .opacity
            }
            result = result.map { $0.combined(with: t) } ?? t
            i += 1
        }
        return result ?? .opacity
    }

    // MARK: - Private Helpers

    private func resolveDoubleValue(_ value: Value<Double>?) -> Value<Double>? {
        guard let value else { return nil }
        if case .expression(let expr) = value {
            if let n = (try? evaluate(expr))?.numberValue {
                return .literal(n)
            }
        }
        return value
    }

    private func resolveStringValue(_ value: Value<String>?) -> Value<String>? {
        guard let value else { return nil }
        if case .expression(let expr) = value {
            return .literal(string(.expression(expr)))
        }
        return value
    }
}
