package com.melody.lua

import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener

/**
 * JNI bridge to Lua 5.4 native library.
 * Values cross the boundary as JSON strings for simplicity and debuggability.
 */
object LuaBridge {
    private val callbacks = mutableMapOf<Int, (Long, List<Any?>) -> Int>()
    private var nextCallbackId = 1

    val LUA_OK: Int by lazy { getLuaOk() }
    val LUA_YIELD: Int by lazy { getLuaYield() }

    init {
        System.loadLibrary("lua_bridge")
    }

    external fun newState(): Long
    external fun closeState(L: Long)
    /** Execute a script. Returns null on success, error string on failure. Leaves result on stack. */
    external fun execute(L: Long, script: String): String?
    /** Evaluate expression, returns JSON-encoded result. Returns error string if starts with error. */
    external fun evaluate(L: Long, expr: String): String
    external fun pushValue(L: Long, json: String)
    external fun getValue(L: Long, index: Int): String
    external fun getGlobal(L: Long, name: String)
    external fun setGlobal(L: Long, name: String)
    external fun pop(L: Long, count: Int)

    external fun registerFunction(L: Long, table: String, name: String, callbackId: Int)

    external fun setTableField(L: Long, table: String, key: String, json: String)
    external fun getTableField(L: Long, table: String, key: String): String

    external fun createStateProxy(L: Long, proxyName: String, dataName: String, callbackId: Int)

    external fun newThread(L: Long): Long
    external fun resumeThread(mainL: Long, coL: Long, nargs: Int, nresultsOut: IntArray): Int
    external fun loadString(L: Long, code: String): Int
    external fun xmove(from: Long, to: Long, n: Int)
    external fun saveRef(L: Long): Int
    external fun releaseRef(L: Long, ref: Int)

    external fun getTop(L: Long): Int
    external fun typeAt(L: Long, index: Int): Int
    external fun getCallbackArgs(L: Long): String
    external fun tableLen(L: Long, index: Int): Long
    external fun rawGetI(L: Long, index: Int, n: Long)

    private external fun getLuaOk(): Int
    private external fun getLuaYield(): Int

    /**
     * Register a Kotlin function to be callable from Lua.
     * @param L The lua_State pointer
     * @param table The Lua table to register the function in (e.g., "melody")
     * @param name The function name within the table
     * @param callback (luaState, args) -> number of return values pushed
     */
    fun registerKotlinFunction(L: Long, table: String, name: String,
                               callback: (Long, List<Any?>) -> Int): Int {
        val id = nextCallbackId++
        callbacks[id] = callback
        registerFunction(L, table, name, id)
        return id
    }

    fun unregisterCallback(id: Int) {
        callbacks.remove(id)
    }

    /**
     * Called from C when a registered Lua function is invoked.
     * @param luaState The lua_State pointer (may be a coroutine)
     * @param callbackId The registered callback ID
     * @return Number of return values pushed onto the Lua stack
     */
    @JvmStatic
    fun dispatchCallback(luaState: Long, callbackId: Int): Int {
        val callback = callbacks[callbackId] ?: return 0

        return try {
            val argsJson = getCallbackArgs(luaState)
            val args = parseJsonArray(argsJson)

            callback(luaState, args)
        } catch (e: Exception) {
            android.util.Log.e("LuaBridge", "Callback $callbackId exception: ${e.message}", e)
            0
        }
    }

    fun toJson(value: Any?): String {
        return when (value) {
            null -> "null"
            is String -> JSONObject.quote(value)
            is Number -> {
                val d = value.toDouble()
                if (d == d.toLong().toDouble() && d < 1e15 && d > -1e15) {
                    value.toLong().toString()
                } else {
                    value.toString()
                }
            }
            is Boolean -> value.toString()
            is Map<*, *> -> {
                val obj = JSONObject()
                for ((k, v) in value) {
                    obj.put(k.toString(), toJsonValue(v))
                }
                obj.toString()
            }
            is List<*> -> {
                val arr = JSONArray()
                for (v in value) {
                    arr.put(toJsonValue(v))
                }
                arr.toString()
            }
            else -> "null"
        }
    }

    private fun toJsonValue(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> {
                val obj = JSONObject()
                for ((k, v) in value) obj.put(k.toString(), toJsonValue(v))
                obj
            }
            is List<*> -> {
                val arr = JSONArray()
                for (v in value) arr.put(toJsonValue(v))
                arr
            }
            else -> value
        }
    }

    fun parseJson(json: String): Any? {
        if (json == "null") return null
        return when (val token = JSONTokener(json).nextValue()) {
            JSONObject.NULL -> null
            is JSONObject -> jsonObjectToMap(token)
            is JSONArray -> jsonArrayToList(token)
            else -> token
        }
    }

    private fun parseJsonArray(json: String): List<Any?> {
        return try {
            val arr = JSONArray(json)
            jsonArrayToList(arr)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun jsonObjectToMap(obj: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        for (key in obj.keys()) {
            map[key] = when (val v = obj.get(key)) {
                JSONObject.NULL -> null
                is JSONObject -> jsonObjectToMap(v)
                is JSONArray -> jsonArrayToList(v)
                else -> v
            }
        }
        return map
    }

    private fun jsonArrayToList(arr: JSONArray): List<Any?> {
        return (0 until arr.length()).map { i ->
            when (val v = arr.get(i)) {
                JSONObject.NULL -> null
                is JSONObject -> jsonObjectToMap(v)
                is JSONArray -> jsonArrayToList(v)
                else -> v
            }
        }
    }
}
