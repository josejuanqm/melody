package com.melody.runtime.state

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import com.melody.core.schema.StateValue
import com.melody.runtime.engine.LuaValue

/**
 * Per-screen state container bridged to Lua.
 * Each key gets its own MutableState<LuaValue> for fine-grained Compose recomposition.
 * Port of iOS ScreenState.swift.
 */
class ScreenState {
    private val slots = mutableMapOf<String, MutableState<LuaValue>>()

    /** Callback to sync changes back to Lua */
    var syncToLua: ((String, LuaValue) -> Unit)? = null

    /** Get or create the MutableState for a given key */
    fun slot(key: String): MutableState<LuaValue> {
        return slots.getOrPut(key) { mutableStateOf(LuaValue.Nil) }
    }

    /** Initialize with state defaults from YAML */
    fun initialize(stateDefaults: Map<String, StateValue>?) {
        stateDefaults?.forEach { (key, stateValue) ->
            slot(key).value = LuaValue.fromStateValue(stateValue)
        }
    }

    /** Update a value (called from Lua metatable __newindex) */
    fun update(key: String, value: LuaValue) {
        slot(key).value = value
    }

    /** Set a value from Compose and sync to Lua */
    fun set(key: String, value: LuaValue) {
        slot(key).value = value
        syncToLua?.invoke(key, value)
    }

    /** Get a value by key */
    fun get(key: String): LuaValue = slot(key).value

    /** Snapshot of all values (NOT for Compose observation) */
    val allValues: Map<String, LuaValue>
        get() = slots.mapValues { it.value.value }
}
