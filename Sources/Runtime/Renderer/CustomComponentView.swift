import SwiftUI
import Core

// MARK: - Environment Keys

private struct CustomComponentsKey: EnvironmentKey {
    static let defaultValue: [String: CustomComponentDefinition] = [:]
}

private struct ComponentPropsKey: EnvironmentKey {
    static let defaultValue: [String: LuaValue]? = nil
}

extension EnvironmentValues {
    var customComponents: [String: CustomComponentDefinition] {
        get { self[CustomComponentsKey.self] }
        set { self[CustomComponentsKey.self] = newValue }
    }

    var componentProps: [String: LuaValue]? {
        get { self[ComponentPropsKey.self] }
        set { self[ComponentPropsKey.self] = newValue }
    }
}

// MARK: - Custom Component View

/// Renders a reusable component template with resolved instance props.
struct CustomComponentView: View {
    let template: CustomComponentDefinition
    let instanceProps: [String: Value<String>]?

    @Environment(\.luaVM) private var luaVM
    @Environment(\.componentProps) private var parentProps

    var body: some View {
        let resolvedProps = resolveProps()
        ComponentRenderer(components: template.body)
            .environment(\.componentProps, resolvedProps)
    }

    private func resolveProps() -> [String: LuaValue] {
        var result: [String: LuaValue] = [:]

        if let defaults = template.props {
            for (key, stateValue) in defaults {
                result[key] = luaValue(from: stateValue)
            }
        }

        if let instanceProps, let vm = luaVM {
            let prefix: String
            if let parentProps {
                prefix = vm.localPrefix(key: "props", for: parentProps)
            } else {
                prefix = ""
            }
            for (key, propValue) in instanceProps {
                switch propValue {
                case .literal(let str):
                    result[key] = .string(str)
                case .expression(let expr):
                    if let value = try? vm.execute(prefix + "return " + expr) {
                        result[key] = value
                    } else {
                        result[key] = .string(expr)
                    }
                }
            }
        }

        return result
    }

    private func luaValue(from stateValue: StateValue) -> LuaValue {
        switch stateValue {
        case .string(let s): return .string(s)
        case .int(let i): return .number(Double(i))
        case .double(let d): return .number(d)
        case .bool(let b): return .bool(b)
        case .null: return .nil
        case .array(let arr): return .array(arr.map { luaValue(from: $0) })
        case .dictionary(let dict): return .table(dict.mapValues { luaValue(from: $0) })
        }
    }
}
