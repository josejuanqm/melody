package com.melody.runtime.engine

import com.melody.core.schema.StateValue

/**
 * Represents a Lua value that can be passed between Kotlin and Lua.
 * Port of iOS LuaValue enum.
 */
sealed class LuaValue {
    data class StringVal(val value: String) : LuaValue()
    data class NumberVal(val value: Double) : LuaValue()
    data class BoolVal(val value: Boolean) : LuaValue()
    data class TableVal(val value: Map<String, LuaValue>) : LuaValue()
    data class ArrayVal(val value: List<LuaValue>) : LuaValue()
    object Nil : LuaValue()

    val stringValue: String?
        get() = (this as? StringVal)?.value

    val numberValue: Double?
        get() = (this as? NumberVal)?.value

    val boolValue: Boolean?
        get() = (this as? BoolVal)?.value

    val tableValue: Map<String, LuaValue>?
        get() = (this as? TableVal)?.value

    val arrayValue: List<LuaValue>?
        get() = (this as? ArrayVal)?.value

    companion object {
        /** Convert a native value (from JSON parsing) to LuaValue */
        fun fromAny(value: Any?): LuaValue = when (value) {
            null -> Nil
            is String -> StringVal(value)
            is Number -> NumberVal(value.toDouble())
            is Boolean -> BoolVal(value)
            is Map<*, *> -> TableVal(
                value.entries.associate { (k, v) -> k.toString() to fromAny(v) }
            )
            is List<*> -> ArrayVal(value.map { fromAny(it) })
            else -> Nil
        }

        /** Convert LuaValue to a native value (for JSON serialization) */
        fun toAny(value: LuaValue): Any? = when (value) {
            is StringVal -> value.value
            is NumberVal -> value.value
            is BoolVal -> value.value
            is TableVal -> value.value.mapValues { toAny(it.value) }
            is ArrayVal -> value.value.map { toAny(it) }
            is Nil -> null
        }

        /** Convert a StateValue to LuaValue */
        fun fromStateValue(sv: StateValue): LuaValue = when (sv) {
            is StateValue.StringVal -> StringVal(sv.value)
            is StateValue.IntVal -> NumberVal(sv.value.toDouble())
            is StateValue.DoubleVal -> NumberVal(sv.value)
            is StateValue.BoolVal -> BoolVal(sv.value)
            is StateValue.NullVal -> Nil
            is StateValue.ArrayVal -> ArrayVal(sv.value.map { fromStateValue(it) })
            is StateValue.DictionaryVal -> TableVal(sv.value.mapValues { fromStateValue(it.value) })
        }
    }
}
