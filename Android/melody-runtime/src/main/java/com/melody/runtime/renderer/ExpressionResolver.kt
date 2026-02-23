package com.melody.runtime.renderer

import com.melody.core.schema.*
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue

/**
 * Centralizes all Lua expression resolution.
 * Mirrors iOS `ExpressionResolver.swift`.
 */
class ExpressionResolver(
    private val vm: LuaVM?,
    private val props: Map<String, LuaValue>?
) {
    private fun propsPrefix(): String {
        return if (vm != null && props != null) vm.propsPrefix(props) else ""
    }

    private fun evaluate(expression: String): LuaValue {
        val prefix = propsPrefix()
        return vm!!.execute("${prefix}return $expression")
    }

    // MARK: - Typed Resolve Methods

    fun string(value: Value<String>?): String {
        if (value == null) return ""
        return when (value) {
            is Value.Literal -> value.value
            is Value.Expression -> {
                if (vm == null) return ""
                try {
                    when (val result = evaluate(value.expr)) {
                        is LuaValue.StringVal -> result.value
                        is LuaValue.NumberVal -> {
                            val n = result.value
                            if (n == n.toLong().toDouble() && n < 1e15) n.toLong().toString() else n.toString()
                        }
                        is LuaValue.BoolVal -> if (result.value) "true" else "false"
                        is LuaValue.Nil -> ""
                        else -> result.toString()
                    }
                } catch (_: Exception) { "" }
            }
        }
    }

    fun number(value: Value<Double>?): Double? {
        if (value == null) return null
        return when (value) {
            is Value.Literal -> value.value
            is Value.Expression -> {
                try { evaluate(value.expr).numberValue } catch (_: Exception) { null }
            }
        }
    }

    fun integer(value: Value<Int>?): Int? {
        if (value == null) return null
        return when (value) {
            is Value.Literal -> value.value
            is Value.Expression -> {
                try { evaluate(value.expr).numberValue?.toInt() } catch (_: Exception) { null }
            }
        }
    }

    fun bool(value: Value<Boolean>?, default: Boolean): Boolean {
        if (value == null || vm == null) return default
        return when (value) {
            is Value.Literal -> value.value
            is Value.Expression -> {
                try {
                    val result = evaluate(value.expr)
                    (result as? LuaValue.BoolVal)?.value ?: default
                } catch (_: Exception) { default }
            }
        }
    }

    fun visible(value: Value<Boolean>?): Boolean {
        if (value == null) return true
        return when (value) {
            is Value.Literal -> value.value
            is Value.Expression -> {
                if (vm == null) return true
                try {
                    when (val result = evaluate(value.expr)) {
                        is LuaValue.BoolVal -> result.value
                        is LuaValue.Nil -> false
                        else -> true
                    }
                } catch (_: Exception) { true }
            }
        }
    }

    fun disabled(value: Value<Boolean>?): Boolean {
        return bool(value, default = false)
    }

    fun direction(value: Value<DirectionAxis>?, default: DirectionAxis = DirectionAxis.Vertical): DirectionAxis {
        if (value == null) return default
        return when (value) {
            is Value.Literal -> value.value
            is Value.Expression -> {
                val resolved = string(Value.Expression(value.expr))
                DirectionAxis.from(resolved)
            }
        }
    }

    fun alignment(value: Value<ViewAlignment>?, default: ViewAlignment = ViewAlignment.Leading): ViewAlignment {
        if (value == null) return default
        return when (value) {
            is Value.Literal -> value.value
            is Value.Expression -> {
                val resolved = string(Value.Expression(value.expr))
                ViewAlignment.from(resolved)
            }
        }
    }

    /** Resolves all Value expressions in a style to Literal values. */
    fun style(style: ComponentStyle?): ComponentStyle? {
        if (style == null || vm == null) return style
        val resolved = style.copy()

        // Resolve color strings
        resolved.color = resolveStringValue(style.color)
        resolved.backgroundColor = resolveStringValue(style.backgroundColor)
        resolved.borderColor = resolveStringValue(style.borderColor)

        // Resolve alignment
        if (style.alignment is Value.Expression) {
            resolved.alignment = Value.Literal(alignment(style.alignment))
        }

        // Resolve all numeric Value<Double> expressions
        resolved.fontSize = resolveDoubleValue(style.fontSize)
        resolved.padding = resolveDoubleValue(style.padding)
        resolved.paddingTop = resolveDoubleValue(style.paddingTop)
        resolved.paddingBottom = resolveDoubleValue(style.paddingBottom)
        resolved.paddingLeft = resolveDoubleValue(style.paddingLeft)
        resolved.paddingRight = resolveDoubleValue(style.paddingRight)
        resolved.paddingHorizontal = resolveDoubleValue(style.paddingHorizontal)
        resolved.paddingVertical = resolveDoubleValue(style.paddingVertical)
        resolved.margin = resolveDoubleValue(style.margin)
        resolved.marginTop = resolveDoubleValue(style.marginTop)
        resolved.marginBottom = resolveDoubleValue(style.marginBottom)
        resolved.marginLeft = resolveDoubleValue(style.marginLeft)
        resolved.marginRight = resolveDoubleValue(style.marginRight)
        resolved.marginHorizontal = resolveDoubleValue(style.marginHorizontal)
        resolved.marginVertical = resolveDoubleValue(style.marginVertical)
        resolved.borderRadius = resolveDoubleValue(style.borderRadius)
        resolved.borderWidth = resolveDoubleValue(style.borderWidth)
        resolved.width = resolveDoubleValue(style.width)
        resolved.height = resolveDoubleValue(style.height)
        resolved.minWidth = resolveDoubleValue(style.minWidth)
        resolved.minHeight = resolveDoubleValue(style.minHeight)
        resolved.maxWidth = resolveDoubleValue(style.maxWidth)
        resolved.maxHeight = resolveDoubleValue(style.maxHeight)
        resolved.spacing = resolveDoubleValue(style.spacing)
        resolved.opacity = resolveDoubleValue(style.opacity)
        resolved.cornerRadius = resolveDoubleValue(style.cornerRadius)
        resolved.scale = resolveDoubleValue(style.scale)
        resolved.rotation = resolveDoubleValue(style.rotation)
        resolved.aspectRatio = resolveDoubleValue(style.aspectRatio)
        resolved.layoutPriority = resolveDoubleValue(style.layoutPriority)

        // Resolve lineLimit
        if (style.lineLimit is Value.Expression) {
            val expr = (style.lineLimit as Value.Expression).expr
            try {
                val n = evaluate(expr).numberValue
                if (n != null) resolved.lineLimit = Value.Literal(n.toInt())
            } catch (_: Exception) {}
        }

        return resolved
    }

    // MARK: - Private Helpers

    private fun resolveDoubleValue(value: Value<Double>?): Value<Double>? {
        if (value == null) return null
        if (value is Value.Expression) {
            try {
                val n = evaluate(value.expr).numberValue
                if (n != null) return Value.Literal(n)
            } catch (_: Exception) {}
        }
        return value
    }

    private fun resolveStringValue(value: Value<String>?): Value<String>? {
        if (value == null) return null
        if (value is Value.Expression) {
            return Value.Literal(string(value))
        }
        return value
    }
}
