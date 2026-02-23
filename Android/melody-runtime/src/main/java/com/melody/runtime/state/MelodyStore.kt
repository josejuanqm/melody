package com.melody.runtime.state

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
class MelodyStore(context: Context? = null) {
    private val cache = mutableMapOf<String, LuaValue>()
    private val prefs: SharedPreferences? = context?.getSharedPreferences("melody_store", Context.MODE_PRIVATE)
    private val prefix = "melody.store."

    /** In-memory only — lost on app restart */
    fun set(key: String, value: LuaValue) {
        cache[key] = value
    }

    /** Persists to SharedPreferences and memory */
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
        } catch (e: Exception) {
            Log.e("MelodyStore", "save($key) error: ${e.message}", e)
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
