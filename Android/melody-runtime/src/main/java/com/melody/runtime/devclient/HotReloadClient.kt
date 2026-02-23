package com.melody.runtime.devclient

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.melody.core.parser.AppParser
import com.melody.core.schema.AppDefinition
import okhttp3.*
import okhttp3.internal.toCanonicalHost

/**
 * Connects to the Melody dev server and receives YAML updates over WebSocket.
 * Port of iOS HotReloadClient.swift.
 *
 * Usage: create in a composable, call connect(), observe latestApp and reloadCount.
 */
class HotReloadClient {
    var latestApp: AppDefinition? by mutableStateOf(null)
        private set
    var isConnected: Boolean by mutableStateOf(false)
        private set
    var reloadCount: Int by mutableIntStateOf(0)
        private set

    private val parser = AppParser()
    private val client = OkHttpClient()
    private var webSocket: WebSocket? = null
    private var shouldReconnect = true
    private var connectUrl: String? = null

    fun connect(host: String = "10.0.2.2", port: Int = 8375) {
        shouldReconnect = true
        connectUrl = "http://$host:$port"
        startConnection()
    }

    fun disconnect() {
        shouldReconnect = false
        webSocket?.close(1000, "Client disconnected")
        webSocket = null
        isConnected = false
    }

    private fun startConnection() {
        val url = connectUrl ?: return

        try {
            java.net.URL(url).host?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            DevLogger.log("Invalid URL: $url", "hotreload")
            Log.e("Melody", "[HotReload] Invalid URL: $url")
            null
        } ?: return

        val request = Request.Builder().url(url).build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                isConnected = true
                DevLogger.log("Connected to $url", "hotreload")
                Log.d("Melody", "[HotReload] Connected to $url")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleYamlUpdate(text)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                isConnected = false
                DevLogger.log("Connection failed: ${t.message}", "hotreload")
                Log.w("Melody", "[HotReload] Connection failed: ${t.message}")

                if (shouldReconnect) {
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        if (shouldReconnect) startConnection()
                    }, 2000)
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                isConnected = false
                if (shouldReconnect) {
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        if (shouldReconnect) startConnection()
                    }, 2000)
                }
            }
        })
    }

    private fun handleYamlUpdate(yaml: String) {
        try {
            val app = parser.parse(yaml)
            latestApp = app
            reloadCount++
            DevLogger.log("Reload #$reloadCount", "hotreload")
            Log.d("Melody", "[HotReload] Reload #$reloadCount")
        } catch (e: Exception) {
            DevLogger.log("Parse error: ${e.message}", "hotreload")
            Log.e("Melody", "[HotReload] Parse error: ${e.message}")
        }
    }
}
