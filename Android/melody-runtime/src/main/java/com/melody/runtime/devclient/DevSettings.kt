package com.melody.runtime.devclient

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

class DevSettings(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("melody_dev", Context.MODE_PRIVATE)

    var hotReloadEnabled: Boolean by mutableStateOf(prefs.getBoolean("hotReloadEnabled", true))
        private set

    var devServerHost: String by mutableStateOf(prefs.getString("devServerHost", "10.0.2.2") ?: "10.0.2.2")
        private set

    var devServerPort: Int by mutableIntStateOf(prefs.getInt("devServerPort", 8375))
        private set

    fun updateHotReloadEnabled(enabled: Boolean) {
        hotReloadEnabled = enabled
        prefs.edit().putBoolean("hotReloadEnabled", enabled).apply()
    }

    fun updateDevServerHost(host: String) {
        devServerHost = host
        prefs.edit().putString("devServerHost", host).apply()
    }

    fun updateDevServerPort(port: Int) {
        devServerPort = port
        prefs.edit().putInt("devServerPort", port).apply()
    }
}
