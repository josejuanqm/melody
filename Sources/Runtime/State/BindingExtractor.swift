import Foundation
import Core

/// Collected `state.*` and `scope.*` key references found in a component's expressions.
struct ComponentBindings {
    var stateKeys: Set<String>
    var scopeKeys: Set<String>
}

/// Static utility that scans a ``ComponentDefinition`` for `state.*` and `scope.*` references.
enum BindingExtractor {
    nonisolated(unsafe) private static let statePattern = #/state\.(\w+)/#
    nonisolated(unsafe) private static let scopePattern = #/scope\.(\w+)/#

    static func bindings(for definition: ComponentDefinition) -> ComponentBindings {
        var stateKeys = Set<String>()
        var scopeKeys = Set<String>()

        // Collect expression strings from Value<T> properties (only .expression cases)
        var expressions: [String] = [
            definition.text?.expressionValue,
            definition.visible?.expressionValue,
            definition.label?.expressionValue,
            definition.src?.expressionValue,
            definition.value?.expressionValue,
            definition.disabled?.expressionValue,
            definition.url?.expressionValue,
            definition.footer?.expressionValue,
            definition.placeholder?.expressionValue,
            definition.transition?.expressionValue,
            definition.columns?.expressionValue,
            definition.minColumnWidth?.expressionValue,
            definition.maxColumnWidth?.expressionValue,
            definition.direction?.expressionValue,
        ].compactMap { $0 }

        // Script properties are always scanned (they're always Lua)
        if let items = definition.items { expressions.append(items) }
        if let render = definition.render { expressions.append(render) }

        if let stateKey = definition.stateKey {
            stateKeys.insert(stateKey)
        }

        if let optionsExpr = definition.options?.expressionString {
            expressions.append(optionsExpr)
        }

        // Style expression values
        let styleExprs: [String?] = [
            definition.style?.color?.expressionValue,
            definition.style?.backgroundColor?.expressionValue,
            definition.style?.borderColor?.expressionValue,
            definition.style?.fontSize?.expressionValue,
            definition.style?.padding?.expressionValue,
            definition.style?.paddingTop?.expressionValue,
            definition.style?.paddingBottom?.expressionValue,
            definition.style?.paddingLeft?.expressionValue,
            definition.style?.paddingRight?.expressionValue,
            definition.style?.paddingHorizontal?.expressionValue,
            definition.style?.paddingVertical?.expressionValue,
            definition.style?.margin?.expressionValue,
            definition.style?.marginTop?.expressionValue,
            definition.style?.marginBottom?.expressionValue,
            definition.style?.marginLeft?.expressionValue,
            definition.style?.marginRight?.expressionValue,
            definition.style?.marginHorizontal?.expressionValue,
            definition.style?.marginVertical?.expressionValue,
            definition.style?.borderRadius?.expressionValue,
            definition.style?.borderWidth?.expressionValue,
            definition.style?.width?.expressionValue,
            definition.style?.height?.expressionValue,
            definition.style?.minWidth?.expressionValue,
            definition.style?.minHeight?.expressionValue,
            definition.style?.maxWidth?.expressionValue,
            definition.style?.maxHeight?.expressionValue,
            definition.style?.spacing?.expressionValue,
            definition.style?.opacity?.expressionValue,
            definition.style?.cornerRadius?.expressionValue,
            definition.style?.scale?.expressionValue,
            definition.style?.rotation?.expressionValue,
            definition.style?.aspectRatio?.expressionValue,
            definition.style?.layoutPriority?.expressionValue,
            definition.style?.alignment?.expressionValue,
            definition.style?.lineLimit?.expressionValue,
        ]
        expressions.append(contentsOf: styleExprs.compactMap { $0 })

        if let props = definition.props {
            expressions.append(contentsOf: props.values.compactMap { $0.expressionValue })
        }

        if let menuItems = definition.contextMenu {
            for item in menuItems {
                if let onTap = item.onTap { expressions.append(onTap) }
            }
        }

        for expr in expressions {
            for match in expr.matches(of: statePattern) {
                stateKeys.insert(String(match.1))
            }
            for match in expr.matches(of: scopePattern) {
                scopeKeys.insert(String(match.1))
            }
        }

        if let explicit = definition.bindings {
            stateKeys.formUnion(explicit)
        }

        return ComponentBindings(stateKeys: stateKeys, scopeKeys: scopeKeys)
    }
}
