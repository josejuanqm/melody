package com.melody.runtime.networking

import android.os.Handler
import android.os.Looper
import okhttp3.*

/**
 * WebSocket wrapper using OkHttp WebSocketListener.
 * Inherits SSL trust from MelodyHTTP's OkHttpClient.
 */
class MelodyWebSocket(
    var onOpen: (() -> Unit)? = null,
    var onMessage: ((String) -> Unit)? = null,
    var onError: ((String) -> Unit)? = null,
    var onClose: ((Int, String?) -> Unit)? = null
) {
    private var webSocket: WebSocket? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Connect to a WebSocket URL with optional headers. */
    fun connect(url: String, headers: Map<String, String>?) {
        val requestBuilder = Request.Builder().url(url)
        headers?.forEach { (key, value) ->
            requestBuilder.addHeader(key, value)
        }

        val client = MelodyHTTP.getClient()
        webSocket = client.newWebSocket(requestBuilder.build(), object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                mainHandler.post { onOpen?.invoke() }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                mainHandler.post { onMessage?.invoke(text) }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                mainHandler.post { onError?.invoke(t.message ?: "WebSocket error") }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(code, reason)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                mainHandler.post { onClose?.invoke(code, reason.ifEmpty { null }) }
            }
        })
    }

    /** Send a text message. Returns true if enqueued successfully. */
    fun send(text: String): Boolean {
        return webSocket?.send(text) ?: false
    }

    /** Close the connection with a code and optional reason. */
    fun close(code: Int = 1000, reason: String? = null) {
        webSocket?.close(code, reason)
    }

    /** Force-close and release all callbacks. */
    fun disconnect() {
        webSocket?.cancel()
        webSocket = null
        onOpen = null
        onMessage = null
        onError = null
        onClose = null
    }
}
