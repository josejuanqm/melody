package com.melody.runtime.networking

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.melody.runtime.engine.LuaValue
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.security.cert.X509Certificate
import javax.net.ssl.*

/**
 * HTTP client for melody.fetch() calls.
 * Port of iOS MelodyHTTP.swift + MelodyURLSession.swift.
 */
object MelodyHTTP {
    private val trustedHosts = mutableSetOf<String>()
    private var client: OkHttpClient = buildClient()
    private var prefs: SharedPreferences? = null
    private const val PREFS_KEY = "melody_trusted_hosts"

    /** Initialize with a Context to enable persistent host trust */
    fun init(context: Context) {
        prefs = context.getSharedPreferences("melody_http", Context.MODE_PRIVATE)
        val saved = prefs?.getStringSet(PREFS_KEY, emptySet()) ?: emptySet()
        if (saved.isNotEmpty()) {
            trustedHosts.addAll(saved)
            client = buildClient()
        }
    }

    private fun buildClient(): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .followRedirects(true)
            .followSslRedirects(true)

        if (trustedHosts.isNotEmpty()) {
            val trustManager = object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            }
            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(null, arrayOf<TrustManager>(trustManager), null)

            builder.sslSocketFactory(sslContext.socketFactory, trustManager)
            builder.hostnameVerifier { hostname, _ -> trustedHosts.contains(hostname) || hostname == "localhost" }
        }

        return builder.build()
    }

    /** Expose the OkHttpClient for reuse (e.g., WebSocket connections inherit SSL trust). */
    fun getClient(): OkHttpClient = client

    fun trustHost(host: String) {
        trustedHosts.add(host)
        client = buildClient()
        prefs?.edit()?.putStringSet(PREFS_KEY, trustedHosts.toSet())?.commit()
    }

    /** Perform an HTTP request and return the result as a LuaValue table */
    fun fetch(url: String, options: Map<String, LuaValue>): LuaValue {
        try {
            val method = (options["method"] as? LuaValue.StringVal)?.value ?: "GET"
            val headers = (options["headers"] as? LuaValue.TableVal)?.value ?: emptyMap()
            val body = options["body"]

            if (url.isEmpty())
                return LuaValue.TableVal(mapOf(
                    "ok" to LuaValue.BoolVal(false),
                    "error" to LuaValue.StringVal("Error, hostname cannot be empty")
                ))
            val requestBuilder = Request.Builder().url(url)

            for ((key, value) in headers) {
                val str = value.stringValue ?: continue
                requestBuilder.addHeader(key, str)
            }

            val requestBody: RequestBody? = when {
                method.uppercase() == "GET" || method.uppercase() == "HEAD" -> null
                body is LuaValue.StringVal -> body.value.toRequestBody("text/plain".toMediaType())
                body is LuaValue.TableVal || body is LuaValue.ArrayVal -> {
                    val json = luaValueToJson(body)
                    json.toRequestBody("application/json".toMediaType())
                }
                else -> null
            }

            requestBuilder.method(method.uppercase(), requestBody)
            val request = requestBuilder.build()

            val response = client.newCall(request).execute()
            val statusCode = response.code
            val responseBody = response.body?.string() ?: ""

            val responseHeaders = mutableMapOf<String, LuaValue>()
            for ((name, value) in response.headers) {
                responseHeaders[name] = LuaValue.StringVal(value)
            }

            val data: LuaValue = try {
                val jsonData = JSONObject(responseBody)
                jsonObjectToLuaValue(jsonData)
            } catch (_: Exception) {
                try {
                    val jsonArray = JSONArray(responseBody)
                    jsonArrayToLuaValue(jsonArray)
                } catch (_: Exception) {
                    LuaValue.StringVal(responseBody)
                }
            }

            val ok = statusCode in 200..399
            return LuaValue.TableVal(mapOf(
                "ok" to LuaValue.BoolVal(ok),
                "status" to LuaValue.NumberVal(statusCode.toDouble()),
                "data" to data,
                "headers" to LuaValue.TableVal(responseHeaders),
                "cookies" to LuaValue.TableVal(emptyMap())
            ))
        } catch (e: Exception) {
            if (isSslError(e)) {
                val host = try { java.net.URL(url).host } catch (_: Exception) { "" }
                return LuaValue.TableVal(mapOf(
                    "ok" to LuaValue.BoolVal(false),
                    "error" to LuaValue.StringVal(e.message ?: "SSL error"),
                    "sslError" to LuaValue.BoolVal(true),
                    "host" to LuaValue.StringVal(host)
                ))
            }
            return LuaValue.TableVal(mapOf(
                "ok" to LuaValue.BoolVal(false),
                "error" to LuaValue.StringVal(e.message ?: "Unknown error")
            ))
        }
    }

    /** Check if an exception (or any of its causes) is SSL-related */
    private fun isSslError(e: Throwable): Boolean {
        var current: Throwable? = e
        while (current != null) {
            if (current is SSLException ||
                current is java.security.cert.CertificateException ||
                current is java.security.cert.CertPathValidatorException) {
                return true
            }
            current = current.cause
        }
        return false
    }

    /** Convert LuaValue to JSON string */
    fun luaValueToJson(value: LuaValue): String = when (value) {
        is LuaValue.StringVal -> JSONObject.quote(value.value)
        is LuaValue.NumberVal -> value.value.let { n ->
            if (n == n.toLong().toDouble()) n.toLong().toString() else n.toString()
        }
        is LuaValue.BoolVal -> value.value.toString()
        is LuaValue.TableVal -> {
            val obj = JSONObject()
            for ((k, v) in value.value) obj.put(k, luaValueToJsonCompatible(v))
            obj.toString()
        }
        is LuaValue.ArrayVal -> {
            val arr = JSONArray()
            for (v in value.value) arr.put(luaValueToJsonCompatible(v))
            arr.toString()
        }
        is LuaValue.Nil -> "null"
    }

    private fun luaValueToJsonCompatible(value: LuaValue): Any = when (value) {
        is LuaValue.StringVal -> value.value
        is LuaValue.NumberVal -> value.value
        is LuaValue.BoolVal -> value.value
        is LuaValue.TableVal -> JSONObject().also { obj ->
            for ((k, v) in value.value) obj.put(k, luaValueToJsonCompatible(v))
        }
        is LuaValue.ArrayVal -> JSONArray().also { arr ->
            for (v in value.value) arr.put(luaValueToJsonCompatible(v))
        }
        is LuaValue.Nil -> JSONObject.NULL
    }

    fun jsonToLuaValue(json: Any?): LuaValue = when (json) {
        null, JSONObject.NULL -> LuaValue.Nil
        is String -> LuaValue.StringVal(json)
        is Number -> LuaValue.NumberVal(json.toDouble())
        is Boolean -> LuaValue.BoolVal(json)
        is JSONObject -> jsonObjectToLuaValue(json)
        is JSONArray -> jsonArrayToLuaValue(json)
        else -> LuaValue.Nil
    }

    private fun jsonObjectToLuaValue(obj: JSONObject): LuaValue {
        val map = mutableMapOf<String, LuaValue>()
        for (key in obj.keys()) {
            map[key] = jsonToLuaValue(obj.opt(key))
        }
        return LuaValue.TableVal(map)
    }

    private fun jsonArrayToLuaValue(arr: JSONArray): LuaValue {
        val list = mutableListOf<LuaValue>()
        for (i in 0 until arr.length()) {
            list.add(jsonToLuaValue(arr.opt(i)))
        }
        return LuaValue.ArrayVal(list)
    }
}
