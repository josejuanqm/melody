package com.melody.runtime.renderer

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import com.melody.core.schema.CustomComponentDefinition
import com.melody.core.schema.Value
import com.melody.runtime.engine.LuaValue

/**
 * Renders a custom component template with resolved props.
 * Port of iOS CustomComponentView.swift.
 */
@Composable
fun CustomComponentView(
    template: CustomComponentDefinition,
    instanceProps: Map<String, Value<String>>?
) {
    val luaVM = LocalLuaVM.current
    val parentProps = LocalComponentProps.current

    val resolvedProps = resolveProps(template, instanceProps, luaVM, parentProps)

    CompositionLocalProvider(
        LocalComponentProps provides resolvedProps
    ) {
        ComponentRenderer(components = template.body)
    }
}

private fun resolveProps(
    template: CustomComponentDefinition,
    instanceProps: Map<String, Value<String>>?,
    luaVM: com.melody.runtime.engine.LuaVM?,
    parentProps: Map<String, LuaValue>?
): Map<String, LuaValue> {
    val result = mutableMapOf<String, LuaValue>()

    template.props?.forEach { (key, stateValue) ->
        result[key] = LuaValue.fromStateValue(stateValue)
    }

    if (instanceProps != null && luaVM != null) {
        val prefix = parentProps?.let { luaVM.propsPrefix(it) } ?: ""
        for ((key, propValue) in instanceProps) {
            when (propValue) {
                is Value.Literal -> result[key] = LuaValue.StringVal(propValue.value)
                is Value.Expression -> {
                    try {
                        result[key] = luaVM.execute("${prefix}return ${propValue.expr}")
                    } catch (_: Exception) {
                        result[key] = LuaValue.StringVal(propValue.expr)
                    }
                }
            }
        }
    }

    return result
}
