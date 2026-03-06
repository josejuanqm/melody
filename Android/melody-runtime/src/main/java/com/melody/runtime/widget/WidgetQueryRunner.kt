package com.melody.runtime.widget

import android.content.Context
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * Lightweight Lua query runner for widget parameter configuration.
 * Creates a minimal LuaVM with only melody.storeGet and melody.fetch registered,
 * loads the app lua prelude for helper functions (e.g. getServers()),
 * and runs query/resolve Lua scripts.
 */
class WidgetQueryRunner(
    private val context: Context,
    private val appLuaPrelude: String? = null
) {
    /**
     * Run a parameter query script with parent parameter values.
     * Returns a list of entity options for the picker.
     */
    suspend fun runQuery(
        queryLua: String,
        params: Map<String, String> = emptyMap()
    ): List<EntityOption> = withContext(Dispatchers.IO) {
        val vm = createVM(params)
        try {
            val result = vm.execute(queryLua)
            parseEntityResults(result)
        } catch (e: Exception) {
            android.util.Log.e("WidgetQueryRunner", "Query error: ${e.message}")
            emptyList()
        }
    }

    /**
     * Run the resolve script with all parameter selections.
     * Returns a flat data map to save as widget config.
     */
    suspend fun runResolve(
        resolveLua: String,
        params: Map<String, String>
    ): Map<String, String> = withContext(Dispatchers.IO) {
        val vm = createVM(params)
        try {
            val result = vm.execute(resolveLua)
            parseResolveResult(result)
        } catch (e: Exception) {
            android.util.Log.e("WidgetQueryRunner", "Resolve error: ${e.message}")
            emptyMap()
        }
    }

    private fun createVM(params: Map<String, String>): LuaVM {
        val vm = LuaVM()

        // Register melody.storeGet(key) — reads from SharedPreferences
        // Uses registerMelodyFunctionJson to push raw JSON directly to Lua,
        // bypassing the LuaValue → toAny → toJson roundtrip which can lose
        // array structure (JSON arrays must become Lua tables with integer keys for ipairs).
        vm.registerMelodyFunctionJson("storeGet") { args ->
            val key = args.firstOrNull()?.stringValue ?: return@registerMelodyFunctionJson null
            val prefs = context.getSharedPreferences("melody_store", Context.MODE_PRIVATE)
            val storeKey = "melody.store.$key"
            val raw = prefs.getString(storeKey, null)
            if (raw == null) {
                android.util.Log.d("WidgetQueryRunner", "storeGet($key): not found in SharedPreferences")
                return@registerMelodyFunctionJson null
            }
            try {
                val json = JSONObject(raw)
                val inner = json.opt("v")
                val result = when (inner) {
                    is org.json.JSONArray -> inner.toString()
                    is JSONObject -> inner.toString()
                    is String -> JSONObject.quote(inner)
                    is Number -> inner.toString()
                    is Boolean -> inner.toString()
                    null, JSONObject.NULL -> "null"
                    else -> "null"
                }
                android.util.Log.d("WidgetQueryRunner", "storeGet($key): pushing json=${result.take(200)}")
                result
            } catch (e: Exception) {
                android.util.Log.e("WidgetQueryRunner", "storeGet($key) parse error: ${e.message}")
                null
            }
        }

        // Register melody.fetch(url, opts) — synchronous HTTP
        vm.registerMelodyFunction("fetch") { args ->
            val url = args.firstOrNull()?.stringValue
                ?: return@registerMelodyFunction LuaValue.TableVal(mapOf("ok" to LuaValue.BoolVal(false)))

            try {
                val opts = args.getOrNull(1)?.tableValue
                val method = opts?.get("method")?.stringValue ?: "GET"
                val headers = opts?.get("headers")?.tableValue?.mapValues { it.value.stringValue ?: "" } ?: emptyMap()

                val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                connection.requestMethod = method
                connection.connectTimeout = 15000
                connection.readTimeout = 15000
                headers.forEach { (k, v) -> connection.setRequestProperty(k, v) }

                // Trust all certificates for self-signed servers
                if (connection is javax.net.ssl.HttpsURLConnection) {
                    val trustAll = arrayOf<javax.net.ssl.TrustManager>(object : javax.net.ssl.X509TrustManager {
                        override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>?, authType: String?) {}
                        override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>?, authType: String?) {}
                        override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
                    })
                    val sc = javax.net.ssl.SSLContext.getInstance("TLS")
                    sc.init(null, trustAll, java.security.SecureRandom())
                    connection.sslSocketFactory = sc.socketFactory
                    connection.hostnameVerifier = javax.net.ssl.HostnameVerifier { _, _ -> true }
                }

                val responseCode = connection.responseCode
                val body = connection.inputStream.bufferedReader().readText()
                connection.disconnect()

                if (responseCode in 200..299) {
                    val data = org.json.JSONTokener(body).nextValue()
                    LuaValue.TableVal(mapOf(
                        "ok" to LuaValue.BoolVal(true),
                        "data" to jsonToLuaValue(data)
                    ))
                } else {
                    LuaValue.TableVal(mapOf("ok" to LuaValue.BoolVal(false)))
                }
            } catch (e: Exception) {
                android.util.Log.e("WidgetQueryRunner", "Fetch error: ${e.message}")
                LuaValue.TableVal(mapOf(
                    "ok" to LuaValue.BoolVal(false),
                    "error" to LuaValue.StringVal(e.message ?: "unknown error")
                ))
            }
        }

        // Register melody.trustHost — no-op in widget context
        vm.registerMelodyFunction("trustHost") { LuaValue.Nil }

        // No-op stubs for functions called by the app prelude
        // (storeSet, storeSave, emit, on, navigate, etc.)
        for (name in listOf("storeSet", "storeSave", "emit", "on", "navigate", "replace",
                            "goBack", "sheet", "dismiss", "alert", "copyToClipboard",
                            "setTitle", "setInterval", "clearInterval", "switchTab")) {
            vm.registerMelodyFunction(name) { LuaValue.Nil }
        }

        // Set params table
        vm.execute("params = {}")
        for ((key, value) in params) {
            vm.setGlobal("params", key, LuaValue.StringVal(value))
        }

        // Load app lua prelude
        appLuaPrelude?.let {
            try { vm.execute(it) } catch (_: Exception) {}
        }

        return vm
    }

    private fun parseEntityResults(result: LuaValue): List<EntityOption> {
        // Query scripts use table.insert which creates integer-keyed arrays (ArrayVal),
        // not string-keyed tables (TableVal). Handle both.
        val items: Collection<LuaValue> = result.arrayValue
            ?: result.tableValue?.values
            ?: return emptyList()
        return items.mapNotNull { item ->
            val itemTable = item.tableValue ?: return@mapNotNull null
            val id = itemTable["id"]?.stringValue ?: return@mapNotNull null
            val name = itemTable["name"]?.stringValue ?: return@mapNotNull null
            val subtitle = itemTable["subtitle"]?.stringValue
            EntityOption(id = id, name = name, subtitle = subtitle)
        }
    }

    private fun parseResolveResult(result: LuaValue): Map<String, String> {
        val table = result.tableValue ?: return emptyMap()
        return table.mapNotNull { (key, value) ->
            val str = when (value) {
                is LuaValue.StringVal -> value.value
                is LuaValue.NumberVal -> {
                    val d = value.value
                    if (d == d.toLong().toDouble()) d.toLong().toString() else d.toString()
                }
                is LuaValue.BoolVal -> value.value.toString()
                else -> return@mapNotNull null
            }
            key to str
        }.toMap()
    }

    private fun jsonToLuaValue(value: Any?): LuaValue {
        return when (value) {
            null -> LuaValue.Nil
            is String -> LuaValue.StringVal(value)
            is Number -> LuaValue.NumberVal(value.toDouble())
            is Boolean -> LuaValue.BoolVal(value)
            is org.json.JSONArray -> {
                val map = mutableListOf<LuaValue>()
                for (i in 0 until value.length()) {
                    val item = jsonToLuaValue(value.get(i))
                    map.add(item)
                }
                LuaValue.ArrayVal(map)
            }
            is org.json.JSONObject -> {
                val map = mutableMapOf<String, LuaValue>()
                for (key in value.keys()) {
                    map[key] = jsonToLuaValue(value.get(key))
                }
                LuaValue.TableVal(map)
            }
            else -> LuaValue.StringVal(value.toString())
        }
    }
}

data class EntityOption(
    val id: String,
    val name: String,
    val subtitle: String? = null
)
