package com.melody.runtime.state

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.melody.runtime.engine.LuaValue
import org.json.JSONObject

/**
 * Cross-screen key-value store.
 * - set/get for ephemeral (in-memory) values
 * - save for persistent values (SharedPreferences)
 * Port of iOS MelodyStore.swift.
 */
class MelodyStore(private val context: Context? = null) {
    private val cache = mutableMapOf<String, LuaValue>()
    private val prefs: SharedPreferences? = context?.getSharedPreferences("melody_store", Context.MODE_PRIVATE)
    private val prefix = "melody.store."

    /** In-memory only — lost on app restart */
    fun set(key: String, value: LuaValue) {
        cache[key] = value
    }

    /** Persists to SharedPreferences and memory, then notifies widgets */
    fun save(key: String, value: LuaValue) {
        Log.d("MelodyStore", "save($key) = $value")
        cache[key] = value
        try {
            val wrapped = JSONObject().apply {
                put("v", luaValueToJsonCompatible(value))
            }
            val json = wrapped.toString()
            Log.d("MelodyStore", "save($key) json=$json prefs=${prefs != null}")
            val ok = prefs?.edit()?.putString(prefix + key, json)?.commit()
            Log.d("MelodyStore", "save($key) commit=$ok")
            notifyWidgets()
        } catch (e: Exception) {
            Log.e("MelodyStore", "save($key) error: ${e.message}", e)
        }
    }

    /**
     * Notifies all Glance-based app widgets that data has changed,
     * triggering a widget refresh in the widget process.
     */
    private fun notifyWidgets() {
        val ctx = context ?: return
        try {
            val manager = AppWidgetManager.getInstance(ctx)
            // Broadcast an update intent to all widget providers.
            // Individual generated widget receivers will pick this up.
            val intent = android.content.Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            intent.setPackage(ctx.packageName)
            ctx.sendBroadcast(intent)
        } catch (e: Exception) {
            Log.w("MelodyStore", "Widget notification failed: ${e.message}")
        }
    }

    /** Reads from memory first, falls back to SharedPreferences */
    fun get(key: String): LuaValue {
        cache[key]?.let {
            Log.d("MelodyStore", "get($key) from cache = $it")
            return it
        }
        try {
            val json = prefs?.getString(prefix + key, null)
            Log.d("MelodyStore", "get($key) from prefs json=$json")
            if (json == null) return LuaValue.Nil
            val wrapped = JSONObject(json)
            val inner = wrapped.opt("v") ?: return LuaValue.Nil
            val value = jsonToLuaValue(inner)
            cache[key] = value
            Log.d("MelodyStore", "get($key) resolved = $value")
            return value
        } catch (e: Exception) {
            Log.e("MelodyStore", "get($key) error: ${e.message}", e)
            return LuaValue.Nil
        }
    }

    /**
     * Returns the raw JSON string for a key's value, suitable for pushing directly to Lua
     * via LuaBridge.pushValue. This bypasses the LuaValue intermediate conversion,
     * preserving JSON arrays as Lua tables with integer keys (required for ipairs).
     * Returns null if the key doesn't exist.
     */
    fun getAsJson(key: String): String? {
        // If value is in cache, convert directly to JSON
        cache[key]?.let { value ->
            return luaValueToJson(value)
        }
        // Otherwise read raw JSON from SharedPreferences and return the inner value as-is
        try {
            val json = prefs?.getString(prefix + key, null) ?: return null
            val wrapped = JSONObject(json)
            val inner = wrapped.opt("v") ?: return null
            // Also populate cache for future get() calls
            val value = jsonToLuaValue(inner)
            cache[key] = value
            // Return the raw inner JSON
            return when (inner) {
                is org.json.JSONArray -> inner.toString()
                is JSONObject -> inner.toString()
                is String -> JSONObject.quote(inner)
                is Number -> inner.toString()
                is Boolean -> inner.toString()
                JSONObject.NULL -> "null"
                else -> "null"
            }
        } catch (e: Exception) {
            Log.e("MelodyStore", "getAsJson($key) error: ${e.message}", e)
            return null
        }
    }

    companion object {
        fun luaValueToJsonCompatible(value: LuaValue): Any? = when (value) {
            is LuaValue.StringVal -> value.value
            is LuaValue.NumberVal -> value.value
            is LuaValue.BoolVal -> value.value
            is LuaValue.TableVal -> {
                val obj = JSONObject()
                for ((k, v) in value.value) {
                    obj.put(k, luaValueToJsonCompatible(v))
                }
                obj
            }
            is LuaValue.ArrayVal -> {
                val arr = org.json.JSONArray()
                for (v in value.value) {
                    arr.put(luaValueToJsonCompatible(v))
                }
                arr
            }
            is LuaValue.Nil -> JSONObject.NULL
        }

        /** Convert LuaValue to a JSON string, preserving array vs object distinction */
        fun luaValueToJson(value: LuaValue): String = when (value) {
            is LuaValue.StringVal -> JSONObject.quote(value.value)
            is LuaValue.NumberVal -> {
                val d = value.value
                if (d == d.toLong().toDouble() && d < 1e15 && d > -1e15) d.toLong().toString()
                else d.toString()
            }
            is LuaValue.BoolVal -> value.value.toString()
            is LuaValue.TableVal -> {
                val obj = JSONObject()
                for ((k, v) in value.value) obj.put(k, luaValueToJsonCompatible(v))
                obj.toString()
            }
            is LuaValue.ArrayVal -> {
                val arr = org.json.JSONArray()
                for (v in value.value) arr.put(luaValueToJsonCompatible(v))
                arr.toString()
            }
            is LuaValue.Nil -> "null"
        }

        fun jsonToLuaValue(json: Any?): LuaValue = when (json) {
            null, JSONObject.NULL -> LuaValue.Nil
            is String -> LuaValue.StringVal(json)
            is Number -> LuaValue.NumberVal(json.toDouble())
            is Boolean -> LuaValue.BoolVal(json)
            is JSONObject -> {
                val map = mutableMapOf<String, LuaValue>()
                for (key in json.keys()) {
                    map[key] = jsonToLuaValue(json.opt(key))
                }
                LuaValue.TableVal(map)
            }
            is org.json.JSONArray -> {
                val list = mutableListOf<LuaValue>()
                for (i in 0 until json.length()) {
                    list.add(jsonToLuaValue(json.opt(i)))
                }
                LuaValue.ArrayVal(list)
            }
            else -> LuaValue.Nil
        }
    }
}
