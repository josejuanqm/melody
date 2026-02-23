package com.melody.runtime.state

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import com.melody.core.schema.StateValue
import com.melody.runtime.engine.LuaValue

/**
 * Component-scoped local state, similar to ScreenState but scoped to a single component.
 * Port of iOS LocalState.swift.
 */
class LocalState {
    private val slots = mutableMapOf<String, MutableState<LuaValue>>()
    /** Mirror of values without triggering Compose tracking */
    private val rawValues = mutableMapOf<String, LuaValue>()

    fun slot(key: String): MutableState<LuaValue> {
        return slots.getOrPut(key) { mutableStateOf(LuaValue.Nil) }
    }

    fun update(key: String, value: LuaValue) {
        slot(key).value = value
        rawValues[key] = value
    }

    fun get(key: String): LuaValue = slot(key).value

    fun initialize(defaults: Map<String, StateValue>?) {
        defaults?.forEach { (key, sv) ->
            val lv = LuaValue.fromStateValue(sv)
            slot(key).value = lv
            rawValues[key] = lv
        }
    }

    /** All values (triggers Compose tracking on every slot) */
    val allValues: Map<String, LuaValue>
        get() = slots.mapValues { it.value.value }

    /** All values without triggering Compose tracking */
    val allValuesUntracked: Map<String, LuaValue>
        get() = rawValues.toMap()
}
