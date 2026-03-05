package com.melody.runtime.widget

import WidgetDefinition
import android.content.Context
import android.util.Log
import org.json.JSONObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager

/**
 * Orchestrates the widget data pipeline:
 *   1. Read store keys from SharedPreferences (same file MelodyStore uses)
 *   2. Fetch URL (optional)
 *   3. Flatten JSON response into a flat string map
 *
 * All values are resolved to strings for expression substitution.
 */
object WidgetDataProvider {

    private const val TAG = "WidgetDataProvider"
    private const val PREFS_NAME = "melody_store"
    private const val PREFIX = "melody.store."

    suspend fun resolve(
        context: Context,
        widget: WidgetDefinition,
        appWidgetId: Int = -1
    ): Map<String, String> {
        val data = mutableMapOf<String, String>()

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        Log.d(TAG, "Resolving widget data. Store keys requested: ${widget.data?.store}")
        widget.data?.store?.forEach { key ->
            val raw = prefs.getString(PREFIX + key, null)
            Log.d(TAG, "  store[$key] raw = $raw")
            if (raw != null) {
                try {
                    val wrapped = JSONObject(raw)
                    val inner = wrapped.opt("v")
                    if (inner != null && inner != JSONObject.NULL) {
                        data[key] = inner.toString()
                        Log.d(TAG, "  store[$key] resolved = ${inner}")
                    } else {
                        Log.d(TAG, "  store[$key] inner was null")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to read store key '$key': ${e.message}")
                }
            } else {
                Log.d(TAG, "  store[$key] not found in prefs")
            }
        }

        if (appWidgetId >= 0) {
            val widgetData = WidgetConfigStore.getData(context, appWidgetId)
            if (widgetData != null) {
                data.putAll(widgetData)
            }
        }

        Log.d(TAG, "Final data map: $data")

        widget.data?.fetch?.let { fetch ->
            try {
                val resolvedUrl = resolveStoreRefs(fetch.url, data)
                val resolvedHeaders = fetch.headers?.mapValues { (_, v) ->
                    resolveStoreRefs(v, data)
                }
                Log.d(TAG, "Fetching: $resolvedUrl")
                val response = withContext(Dispatchers.IO) {
                    httpGet(context, resolvedUrl, resolvedHeaders)
                }
                if (response != null) {
                    flattenJson(JSONObject(response), "", data)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Fetch failed: ${e}")
            }
        }

        return data
    }

    /**
     * Replaces `{{ data.key }}` references in a string with resolved values.
     */
    private fun resolveStoreRefs(value: String, data: Map<String, String>): String {
        return value.replace(Regex("\\{\\{\\s*data\\.([\\w.]+)\\s*\\}\\}")) { match ->
            data[match.groupValues[1]] ?: ""
        }
    }

    private val trustManager = object : X509TrustManager {
        override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
        override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
    }

    private val sslContext: SSLContext by lazy {
        SSLContext.getInstance("TLS").apply {
            init(null, arrayOf(trustManager), null)
        }
    }

    private fun getTrustedHosts(context: Context): Set<String> {
        return context.getSharedPreferences("melody_http", Context.MODE_PRIVATE)
            .getStringSet("melody_trusted_hosts", emptySet()) ?: emptySet()
    }

    /**
     * Simple HTTP GET request. Runs on the caller's coroutine dispatcher.
     * Trusts only hosts registered via melody.trustHost() in the main app.
     */
    private fun httpGet(context: Context, urlString: String, headers: Map<String, String>?): String? {
        val conn = URL(urlString).openConnection() as HttpURLConnection
        if (conn is HttpsURLConnection) {
            val host = URL(urlString).host
            val trustedHosts = getTrustedHosts(context)
            if (trustedHosts.contains(host)) {
                conn.sslSocketFactory = sslContext.socketFactory
                conn.hostnameVerifier = javax.net.ssl.HostnameVerifier { h, _ -> trustedHosts.contains(h) }
            }
        }
        return try {
            conn.requestMethod = "GET"
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            headers?.forEach { (k, v) -> conn.setRequestProperty(k, v) }
            if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                conn.inputStream.bufferedReader().readText()
            } else {
                Log.w(TAG, "HTTP ${conn.responseCode} for $urlString")
                null
            }
        } finally {
            conn.disconnect()
        }
    }

    /**
     * Flattens a JSON object into a flat key→string map.
     * Nested keys use dot notation: `{ "user": { "name": "Alice" } }` → `user.name = "Alice"`
     */
    private fun flattenJson(
        json: JSONObject,
        prefix: String,
        out: MutableMap<String, String>
    ) {
        for (key in json.keys()) {
            val fullKey = if (prefix.isEmpty()) key else "$prefix.$key"
            when (val value = json.get(key)) {
                is JSONObject -> flattenJson(value, fullKey, out)
                JSONObject.NULL -> { /* skip nulls */ }
                else -> out[fullKey] = value.toString()
            }
        }
    }
}
