package com.melody.runtime.state

import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.Value

data class ComponentBindings(
    val stateKeys: Set<String>,
    val scopeKeys: Set<String>
)

/**
 * Extracts state.xxx and scope.xxx references from component definitions
 * for automatic, minimal state subscriptions.
 * Port of iOS BindingExtractor.swift.
 */
object BindingExtractor {
    private val statePattern = Regex("""state\.(\w+)""")
    private val scopePattern = Regex("""scope\.(\w+)""")

    fun bindings(definition: ComponentDefinition): ComponentBindings {
        val stateKeys = mutableSetOf<String>()
        val scopeKeys = mutableSetOf<String>()

        val expressions = mutableListOf<String>()

        // Scan Value<T> expression variants
        listOfNotNull(
            definition.text?.expressionValue,
            definition.visible?.expressionValue,
            definition.label?.expressionValue,
            definition.src?.expressionValue,
            definition.value?.expressionValue,
            definition.disabled?.expressionValue,
            definition.systemImage?.expressionValue,
            definition.url?.expressionValue,
            definition.footer?.expressionValue,
            definition.placeholder?.expressionValue,
            definition.transition?.expressionValue,
            definition.columns?.expressionValue,
            definition.direction?.expressionValue
        ).let { expressions.addAll(it) }

        // Script properties (items, render) scanned in full
        listOfNotNull(definition.items, definition.render).let { expressions.addAll(it) }

        definition.stateKey?.let { stateKeys.add(it) }

        definition.options?.expressionString?.let { expressions.add(it) }

        // Scan style Value<String> color expression values
        listOfNotNull(
            definition.style?.backgroundColor?.expressionValue,
            definition.style?.color?.expressionValue,
            definition.style?.borderColor?.expressionValue,
            definition.style?.alignment?.expressionValue
        ).let { expressions.addAll(it) }

        // Scan style Value<Double> expression values
        listOfNotNull(
            definition.style?.fontSize?.expressionValue,
            definition.style?.opacity?.expressionValue,
            definition.style?.scale?.expressionValue,
            definition.style?.rotation?.expressionValue,
            definition.style?.width?.expressionValue,
            definition.style?.height?.expressionValue,
            definition.style?.spacing?.expressionValue,
            definition.style?.padding?.expressionValue,
            definition.style?.lineLimit?.expressionValue
        ).let { expressions.addAll(it) }

        // Scan props expression values
        definition.props?.values?.mapNotNull { it.expressionValue }?.let { expressions.addAll(it) }

        definition.contextMenu?.forEach { item ->
            item.onTap?.let { expressions.add(it) }
        }

        for (expr in expressions) {
            statePattern.findAll(expr).forEach { stateKeys.add(it.groupValues[1]) }
            scopePattern.findAll(expr).forEach { scopeKeys.add(it.groupValues[1]) }
        }

        definition.bindings?.let { stateKeys.addAll(it) }

        return ComponentBindings(stateKeys, scopeKeys)
    }
}
