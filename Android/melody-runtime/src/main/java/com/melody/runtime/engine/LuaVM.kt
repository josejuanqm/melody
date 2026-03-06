package com.melody.runtime.engine

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.melody.lua.LuaBridge
import com.melody.runtime.networking.MelodyHTTP
import kotlinx.coroutines.*

/**
 * Manages a Lua virtual machine instance.
 * Port of iOS LuaVM.swift.
 */
class LuaVM {
    companion object {
        /** Set from the app context to reliably detect debug builds */
        var isDebugBuild: Boolean = false
    }

    private val L: Long = LuaBridge.newState()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val registeredCallbackIds = mutableListOf<Int>()

    /** Active interval timers keyed by ID */
    private val timers = mutableMapOf<Int, Runnable>()
    private var timerNextId = 0

    /** Coroutine scope for async operations (fetch, etc.) */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var isClosed = false

    /** Callback invoked when the `state` table is modified from Lua */
    var onStateChanged: ((String, LuaValue) -> Unit)? = null

    /** Callback invoked when the `scope` table is modified from Lua */
    var onScopeChanged: ((String, LuaValue) -> Unit)? = null

    init {
        setupStateTable()
        setupScopeTable()
        setupMelodyTable()
        setupGlobalUtilities()
    }

    fun close() {
        if (isClosed) return
        isClosed = true
        scope.cancel()
        invalidateAllTimers()
        for (id in registeredCallbackIds) {
            LuaBridge.unregisterCallback(id)
        }
        registeredCallbackIds.clear()
        LuaBridge.closeState(L)
    }

    /** Cancel all active interval timers */
    fun invalidateAllTimers() {
        for ((_, runnable) in timers) {
            mainHandler.removeCallbacks(runnable)
        }
        timers.clear()
    }

    /** Execute a Lua script string. Returns the result or throws. */
    fun execute(script: String): LuaValue {
        if (isClosed) return LuaValue.Nil
        val error = LuaBridge.execute(L, script)
        if (error != null) {
            throw LuaError.RuntimeError(error)
        }
        val json = LuaBridge.getValue(L, -1)
        LuaBridge.pop(L, 1)
        return LuaValue.fromAny(LuaBridge.parseJson(json))
    }

    /** Evaluate a Lua expression and return its value */
    fun evaluate(expression: String): LuaValue {
        if (isClosed) return LuaValue.Nil
        return execute("return $expression")
    }

    /** Set a value in the Lua `state` table (triggers onStateChanged) */
    fun setState(key: String, value: LuaValue) {
        if (isClosed) return
        LuaBridge.setTableField(L, "state", key, LuaBridge.toJson(LuaValue.toAny(value)))
    }

    /** Set a value in the backing table WITHOUT triggering onStateChanged */
    fun setStateRaw(key: String, value: LuaValue) {
        if (isClosed) return
        LuaBridge.setTableField(L, "_state_data", key, LuaBridge.toJson(LuaValue.toAny(value)))
    }

    /** Get a value from the Lua `state` table */
    fun getState(key: String): LuaValue {
        if (isClosed) return LuaValue.Nil
        val json = LuaBridge.getTableField(L, "_state_data", key)
        return LuaValue.fromAny(LuaBridge.parseJson(json))
    }

    /** Set multiple state values at once */
    fun setInitialState(state: Map<String, LuaValue>) {
        for ((key, value) in state) {
            setState(key, value)
        }
    }

    fun setScopeState(key: String, value: LuaValue) {
        if (isClosed) return
        LuaBridge.setTableField(L, "_scope_data", key, LuaBridge.toJson(LuaValue.toAny(value)))
    }

    fun clearScope() {
        if (isClosed) return
        execute("_scope_data = {}")
    }

    fun setGlobal(name: String, value: LuaValue) {
        if (isClosed) return
        LuaBridge.pushValue(L, LuaBridge.toJson(LuaValue.toAny(value)))
        LuaBridge.setGlobal(L, name)
    }

    fun setGlobal(table: String, key: String, value: LuaValue) {
        if (isClosed) return
        LuaBridge.setTableField(L, table, key, LuaBridge.toJson(LuaValue.toAny(value)))
    }

    /** Generate a Lua `local props = { ... }` prefix for self-contained evaluation */
    fun propsPrefix(props: Map<String, LuaValue>): String {
        val parts = props.map { (key, value) ->
            val escapedKey = key.replace("\"", "\\\"")
            "[\"$escapedKey\"] = ${luaLiteral(value)}"
        }
        return "local props = {${parts.joinToString(", ")}}\n"
    }

    private fun luaLiteral(value: LuaValue): String = when (value) {
        is LuaValue.StringVal -> {
            val escaped = value.value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\u0000", "\\0")
            "\"$escaped\""
        }
        is LuaValue.NumberVal -> {
            val n = value.value
            if (n == n.toLong().toDouble() && n >= Long.MIN_VALUE.toDouble() && n <= Long.MAX_VALUE.toDouble()) {
                n.toLong().toString()
            } else {
                n.toString()
            }
        }
        is LuaValue.BoolVal -> if (value.value) "true" else "false"
        is LuaValue.Nil -> "nil"
        is LuaValue.TableVal -> {
            val entries = value.value.map { "[\"${it.key}\"] = ${luaLiteral(it.value)}" }
            "{${entries.joinToString(", ")}}"
        }
        is LuaValue.ArrayVal -> {
            "{${value.value.joinToString(", ") { luaLiteral(it) }}}"
        }
    }

    /** Register a Kotlin function callable from Lua via melody.functionName */
    fun registerMelodyFunction(name: String, function: (List<LuaValue>) -> LuaValue) {
        val id = LuaBridge.registerKotlinFunction(L, "melody", name) { luaState, rawArgs ->
            val args = rawArgs.map { LuaValue.fromAny(it) }
            val result = function(args)
            LuaBridge.pushValue(luaState, LuaBridge.toJson(LuaValue.toAny(result)))
            1
        }
        registeredCallbackIds.add(id)
    }

    /**
     * Register a Kotlin function that returns a raw JSON string to push directly to Lua.
     * Bypasses the LuaValue → toAny → toJson roundtrip for better fidelity
     * (e.g., preserves JSON arrays as Lua tables with integer keys for ipairs).
     * Return null to push nil.
     */
    fun registerMelodyFunctionJson(name: String, function: (List<LuaValue>) -> String?) {
        val id = LuaBridge.registerKotlinFunction(L, "melody", name) { luaState, rawArgs ->
            val args = rawArgs.map { LuaValue.fromAny(it) }
            val json = function(args)
            LuaBridge.pushValue(luaState, json ?: "null")
            1
        }
        registeredCallbackIds.add(id)
    }

    /**
     * Register a Kotlin function under a plugin namespace (e.g., `keychain.get`).
     * Creates the namespace table as a global if it doesn't exist yet.
     */
    fun registerPluginFunction(namespace: String, name: String, function: (List<LuaValue>) -> LuaValue) {
        execute("$namespace = $namespace or {}")
        val id = LuaBridge.registerKotlinFunction(L, namespace, name) { luaState, rawArgs ->
            val args = rawArgs.map { LuaValue.fromAny(it) }
            val result = function(args)
            LuaBridge.pushValue(luaState, LuaBridge.toJson(LuaValue.toAny(result)))
            1
        }
        registeredCallbackIds.add(id)
    }

    /** Execute a Lua script as a coroutine that can yield for async operations */
    fun executeAsync(script: String, completion: (Result<LuaValue>) -> Unit) {
        if (isClosed) { completion(Result.success(LuaValue.Nil)); return }
        val co = LuaBridge.newThread(L)
        val ref = LuaBridge.saveRef(L)

        val loadStatus = LuaBridge.loadString(co, script)
        if (loadStatus != LuaBridge.LUA_OK) {
            val errorJson = LuaBridge.getValue(co, -1)
            LuaBridge.pop(co, 1)
            LuaBridge.releaseRef(L, ref)
            completion(Result.failure(LuaError.SyntaxError(errorJson)))
            return
        }

        resumeCoroutine(co, ref, 0, completion)
    }

    private fun resumeCoroutine(co: Long, ref: Int, nargs: Int, completion: (Result<LuaValue>) -> Unit) {
        if (isClosed) { completion(Result.success(LuaValue.Nil)); return }
        val nresultsOut = IntArray(1)
        val status = LuaBridge.resumeThread(L, co, nargs, nresultsOut)
        val nresults = nresultsOut[0]

        when (status) {
            LuaBridge.LUA_OK -> {
                val result = if (nresults > 0) {
                    val json = LuaBridge.getValue(co, -1)
                    LuaBridge.pop(co, nresults)
                    LuaValue.fromAny(LuaBridge.parseJson(json))
                } else {
                    LuaValue.Nil
                }
                LuaBridge.releaseRef(L, ref)
                completion(Result.success(result))
            }
            LuaBridge.LUA_YIELD -> {
                val tagJson = if (nresults > 0) LuaBridge.getValue(co, -nresults) else "null"
                val tag = LuaBridge.parseJson(tagJson)

                if (tag == "__fetch__" && nresults >= 2) {
                    val urlJson = LuaBridge.getValue(co, -nresults + 1)
                    val optionsJson = if (nresults >= 3) LuaBridge.getValue(co, -nresults + 2) else "{}"
                    LuaBridge.pop(co, nresults)

                    val urlValue = LuaValue.fromAny(LuaBridge.parseJson(urlJson))
                    val optionsValue = LuaValue.fromAny(LuaBridge.parseJson(optionsJson))

                    handleFetchYield(co, ref, urlValue, optionsValue, completion)
                } else if (tag == "__fetch_all__" && nresults >= 2) {
                    val requestsJson = LuaBridge.getValue(co, -nresults + 1)
                    LuaBridge.pop(co, nresults)

                    val requestsValue = LuaValue.fromAny(LuaBridge.parseJson(requestsJson))

                    handleFetchAllYield(co, ref, requestsValue, completion)
                } else {
                    if (nresults > 0) LuaBridge.pop(co, nresults)
                    LuaBridge.releaseRef(L, ref)
                    completion(Result.success(LuaValue.Nil))
                }
            }
            else -> {
                val errorJson = LuaBridge.getValue(co, -1)
                LuaBridge.releaseRef(L, ref)
                completion(Result.failure(LuaError.RuntimeError(errorJson)))
            }
        }
    }

    private fun handleFetchYield(
        co: Long, ref: Int,
        url: LuaValue,
        options: LuaValue,
        completion: (Result<LuaValue>) -> Unit
    ) {
        val urlString = url.stringValue
        if (urlString == null) {
            val errorResult = LuaValue.TableVal(mapOf(
                "ok" to LuaValue.BoolVal(false),
                "error" to LuaValue.StringVal("Invalid URL")
            ))
            LuaBridge.pushValue(co, LuaBridge.toJson(LuaValue.toAny(errorResult)))
            resumeCoroutine(co, ref, 1, completion)
            return
        }

        scope.launch {
            val result = MelodyHTTP.fetch(urlString, options.tableValue ?: emptyMap())
            withContext(Dispatchers.Main) {
                if (isClosed) return@withContext
                LuaBridge.pushValue(co, LuaBridge.toJson(LuaValue.toAny(result)))
                resumeCoroutine(co, ref, 1, completion)
            }
        }
    }

    private fun handleFetchAllYield(
        co: Long, ref: Int,
        requests: LuaValue,
        completion: (Result<LuaValue>) -> Unit
    ) {
        val requestList: List<LuaValue> = when (requests) {
            is LuaValue.ArrayVal -> requests.value
            is LuaValue.TableVal -> {
                requests.value.keys
                    .mapNotNull { it.toIntOrNull() }
                    .sorted()
                    .map { requests.value[it.toString()] ?: LuaValue.Nil }
            }
            else -> {
                val errorResult = LuaValue.TableVal(mapOf(
                    "ok" to LuaValue.BoolVal(false),
                    "error" to LuaValue.StringVal("fetchAll requires an array of requests")
                ))
                LuaBridge.pushValue(co, LuaBridge.toJson(LuaValue.toAny(errorResult)))
                resumeCoroutine(co, ref, 1, completion)
                return
            }
        }

        if (requestList.isEmpty()) {
            LuaBridge.pushValue(co, LuaBridge.toJson(emptyList<Any>()))
            resumeCoroutine(co, ref, 1, completion)
            return
        }

        data class RequestSpec(val index: Int, val url: String, val options: Map<String, LuaValue>)

        val specs = mutableListOf<RequestSpec>()
        for ((i, spec) in requestList.withIndex()) {
            val table = spec.tableValue ?: continue
            val urlVal = (table["url"] as? LuaValue.StringVal)?.value ?: continue
            val opts = table["options"]?.tableValue ?: emptyMap()
            specs.add(RequestSpec(i, urlVal, opts))
        }

        val results = Array<LuaValue>(requestList.size) {
            LuaValue.TableVal(mapOf(
                "ok" to LuaValue.BoolVal(false),
                "error" to LuaValue.StringVal("Skipped")
            ))
        }

        scope.launch {
            val jobs = specs.map { spec ->
                async {
                    val result = MelodyHTTP.fetch(spec.url, spec.options)
                    spec.index to result
                }
            }

            val fetchResults = jobs.awaitAll()
            for ((index, result) in fetchResults) {
                results[index] = result
            }

            withContext(Dispatchers.Main) {
                if (isClosed) return@withContext
                val resultList = LuaValue.ArrayVal(results.toList())
                LuaBridge.pushValue(co, LuaBridge.toJson(LuaValue.toAny(resultList)))
                resumeCoroutine(co, ref, 1, completion)
            }
        }
    }

    /** Dispatch an event to this VM's Lua listeners */
    fun dispatchEvent(name: String, data: LuaValue) {
        if (isClosed) return

        val listenersJson = LuaBridge.getTableField(L, "_melody_event_listeners", name)
        val listeners = LuaBridge.parseJson(listenersJson)
        if (listeners !is List<*>) return

        val listLen = listeners.size
        if (listLen == 0) return

        val dataJson = LuaBridge.toJson(LuaValue.toAny(data))
        val script = """
            local listeners = _melody_event_listeners["$name"]
            if listeners then
                for _, cb in ipairs(listeners) do
                    cb(_jni_event_data)
                end
            end
        """.trimIndent()

        LuaBridge.pushValue(L, dataJson)
        LuaBridge.setGlobal(L, "_jni_event_data")

        executeAsync(script) { result ->
            if (result.isFailure) {
                android.util.Log.w("Melody", "Event '$name' handler error: ${result.exceptionOrNull()?.message}")
            }
        }
    }

    private fun setupStateTable() {
        val callbackId = LuaBridge.registerKotlinFunction(L, "_internal", "_stateChanged") { luaState, args ->
            if (args.size >= 2) {
                val key = args[0]?.toString() ?: return@registerKotlinFunction 0
                val value = LuaValue.fromAny(args[1])
                mainHandler.post {
                    onStateChanged?.invoke(key, value)
                }
            }
            0
        }
        registeredCallbackIds.add(callbackId)

        LuaBridge.createStateProxy(L, "state", "_state_data", callbackId)
    }

    private fun setupScopeTable() {
        val callbackId = LuaBridge.registerKotlinFunction(L, "_internal", "_scopeChanged") { luaState, args ->
            if (args.size >= 2) {
                val key = args[0]?.toString() ?: return@registerKotlinFunction 0
                val value = LuaValue.fromAny(args[1])
                onScopeChanged?.invoke(key, value)
            }
            0
        }
        registeredCallbackIds.add(callbackId)

        LuaBridge.createStateProxy(L, "scope", "_scope_data", callbackId)
    }

    private fun setupGlobalUtilities() {
        try {
            execute("""
                function urlEncode(str)
                    if type(str) ~= "string" then return "" end
                    str = string.gsub(str, "([^%w%-%.%_%~])", function(c)
                        return string.format("%%%02X", string.byte(c))
                    end)
                    return str
                end

                function urlDecode(str)
                    if type(str) ~= "string" then return "" end
                    str = string.gsub(str, "%%(%x%x)", function(h)
                        return string.char(tonumber(h, 16))
                    end)
                    return str
                end

                function asset(path)
                    return "assets/" .. path
                end
            """.trimIndent())
        } catch (e: Exception) {
            android.util.Log.e("LuaVM", "Failed to setup global utilities: ${e.message}")
        }
    }

    private fun setupMelodyTable() {
        setGlobal("platform", LuaValue.StringVal("android"))
        setGlobal("isDebug", LuaValue.BoolVal(isDebugBuild))

        val logId = LuaBridge.registerKotlinFunction(L, "melody", "log") { _, args ->
            val msg = args.firstOrNull()?.toString() ?: ""
            android.util.Log.d("melody.log", msg)
            com.melody.runtime.devclient.DevLogger.log(msg, "lua")
            0
        }
        registeredCallbackIds.add(logId)

        try {
            execute("""
                melody.fetch = function(url, options)
                    return coroutine.yield("__fetch__", url, options or {})
                end
            """.trimIndent())
        } catch (e: Exception) {
            android.util.Log.e("LuaVM", "Failed to setup melody.fetch: ${e.message}")
        }

        try {
            execute("""
                melody.fetchAll = function(requests)
                    return coroutine.yield("__fetch_all__", requests)
                end
            """.trimIndent())
        } catch (e: Exception) {
            android.util.Log.e("LuaVM", "Failed to setup melody.fetchAll: ${e.message}")
        }

        val startTimerId = LuaBridge.registerKotlinFunction(L, "melody", "_startTimer") { _, args ->
            val timerId = (args.getOrNull(0) as? Number)?.toInt() ?: return@registerKotlinFunction 0
            val intervalMs = (args.getOrNull(1) as? Number)?.toLong() ?: return@registerKotlinFunction 0

            val runnable = object : Runnable {
                override fun run() {
                    executeAsync("""
                        local cb = _melody_timers[$timerId]
                        if cb then cb() end
                    """.trimIndent()) { _ -> }
                    mainHandler.postDelayed(this, intervalMs)
                }
            }
            timers[timerId] = runnable
            mainHandler.postDelayed(runnable, intervalMs)
            0
        }
        registeredCallbackIds.add(startTimerId)

        val stopTimerId = LuaBridge.registerKotlinFunction(L, "melody", "_stopTimer") { _, args ->
            val timerId = (args.getOrNull(0) as? Number)?.toInt() ?: return@registerKotlinFunction 0
            timers[timerId]?.let { mainHandler.removeCallbacks(it) }
            timers.remove(timerId)
            0
        }
        registeredCallbackIds.add(stopTimerId)

        try {
            execute("""
                _melody_timers = {}
                _melody_timer_id = 0

                melody.setInterval = function(callback, ms)
                    _melody_timer_id = _melody_timer_id + 1
                    local id = _melody_timer_id
                    _melody_timers[id] = callback
                    melody._startTimer(id, ms)
                    return id
                end

                melody.clearInterval = function(id)
                    if id then
                        _melody_timers[id] = nil
                        melody._stopTimer(id)
                    end
                end
            """.trimIndent())
        } catch (e: Exception) {
            android.util.Log.e("LuaVM", "Failed to setup melody.setInterval: ${e.message}")
        }
    }
}

sealed class LuaError(message: String) : Exception(message) {
    class RuntimeError(msg: String) : LuaError("Lua runtime error: $msg")
    class SyntaxError(msg: String) : LuaError("Lua syntax error: $msg")
    class MemoryError : LuaError("Lua memory error")
    class InitializationFailed : LuaError("Failed to initialize Lua VM")
}
