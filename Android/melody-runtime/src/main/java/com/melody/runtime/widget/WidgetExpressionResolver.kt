package com.melody.runtime.widget

import android.util.Log
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.ComponentStyle
import com.melody.core.schema.Value
import com.melody.core.schema.resolved

/**
 * Single-pass resolver that walks a component tree and replaces
 * `{{ data.xxx }}` expressions with literal values from the data map.
 * Returns a new component tree with zero expressions remaining.
 */
object WidgetExpressionResolver {

    private const val TAG = "WidgetExprResolver"

    fun resolveValue(value: Value<String>?, data: Map<String, String>): String? {
        return resolveStringValue(value, data)?.literalValue
    }

    fun resolve(
        components: List<ComponentDefinition>,
        data: Map<String, String>
    ): List<ComponentDefinition> {
        Log.d(TAG, "Resolving ${components.size} components with data keys: ${data.keys}")
        return components.mapNotNull { comp ->
            val resolved = resolveComponent(comp, data)
            val vis = resolved.visible?.literalValue
            if (vis == false) {
                Log.d(TAG, "  Filtered out invisible ${comp.component}")
                null
            } else {
                resolved
            }
        }
    }

    private fun resolveComponent(
        def: ComponentDefinition,
        data: Map<String, String>
    ): ComponentDefinition {
        return def.copy(
            text = resolveStringValue(def.text, data),
            label = resolveStringValue(def.label, data),
            src = resolveStringValue(def.src, data),
            value = resolveStringValue(def.value, data),
            systemImage = resolveStringValue(def.systemImage, data),
            url = resolveStringValue(def.url, data),
            placeholder = resolveStringValue(def.placeholder, data),
            visible = resolveBoolValue(def.visible, data),
            style = resolveStyle(def.style, data),
            children = def.children?.let { resolve(it, data) }
        )
    }

    private fun resolveBoolValue(
        value: Value<Boolean>?,
        data: Map<String, String>
    ): Value<Boolean>? {
        if (value == null) return null
        return when (value) {
            is Value.Literal -> value
            is Value.Expression -> Value.Literal(evaluateBoolExpression(value.expr, data))
        }
    }

    /**
     * Evaluates common Lua-style boolean expressions against the data map.
     * Supports patterns like:
     *   - `data.X` → truthy (non-empty)
     *   - `data.X and data.Y` → both truthy
     *   - `data.X and data.X ~= ''` → non-empty check
     *   - `not data.X` → falsy
     *   - `data.X == 'value'` → equality
     *   - `data.X ~= 'value'` → inequality
     */
    private fun evaluateBoolExpression(expr: String, data: Map<String, String>): Boolean {
        val trimmed = expr.trim()

        // Split on " and " / " or " for compound expressions
        val andIdx = trimmed.indexOf(" and ")
        if (andIdx >= 0) {
            val left = trimmed.substring(0, andIdx)
            val right = trimmed.substring(andIdx + 5)
            return evaluateBoolExpression(left, data) && evaluateBoolExpression(right, data)
        }
        val orIdx = trimmed.indexOf(" or ")
        if (orIdx >= 0) {
            val left = trimmed.substring(0, orIdx)
            val right = trimmed.substring(orIdx + 4)
            return evaluateBoolExpression(left, data) || evaluateBoolExpression(right, data)
        }

        // "not data.X"
        if (trimmed.startsWith("not ")) {
            val inner = trimmed.removePrefix("not ").trim()
            return !evaluateBoolExpression(inner, data)
        }

        // "data.X ~= 'value'" or "data.X ~= ''"
        val neqMatch = Regex("""data\.(\w+)\s*~=\s*'([^']*)'""").find(trimmed)
        if (neqMatch != null) {
            val key = neqMatch.groupValues[1]
            val cmp = neqMatch.groupValues[2]
            return (data[key] ?: "") != cmp
        }

        // "data.X == 'value'"
        val eqMatch = Regex("""data\.(\w+)\s*==\s*'([^']*)'""").find(trimmed)
        if (eqMatch != null) {
            val key = eqMatch.groupValues[1]
            val cmp = eqMatch.groupValues[2]
            return (data[key] ?: "") == cmp
        }

        // "data.X" — truthy check (exists and non-empty)
        val dataRef = Regex("""^data\.(\w+)$""").find(trimmed)
        if (dataRef != null) {
            val key = dataRef.groupValues[1]
            val v = data[key] ?: ""
            return v.isNotEmpty()
        }

        // Fallback: resolve string and check truthiness
        val resolved = resolveExpressionString(trimmed, data)
        return resolved.isNotEmpty() && resolved != "false" && resolved != "0"
    }

    private fun resolveStringValue(
        value: Value<String>?,
        data: Map<String, String>
    ): Value<String>? {
        if (value == null) return null
        return when (value) {
            is Value.Literal -> value
            is Value.Expression -> {
                val resolved = resolveExpressionString(value.expr, data)
                Value.Literal(resolved)
            }
        }
    }

    private fun resolveExpressionString(expr: String, data: Map<String, String>): String {
        return expr.replace(Regex("data\\.([\\w.]+)")) { match ->
            data[match.groupValues[1]] ?: ""
        }
    }

    private fun resolveStyle(
        style: ComponentStyle?,
        data: Map<String, String>
    ): ComponentStyle? {
        if (style == null) return null
        return style.copy(
            color = resolveStringValue(style.color, data),
            backgroundColor = resolveStringValue(style.backgroundColor, data),
            borderColor = resolveStringValue(style.borderColor, data)
        )
    }
}
