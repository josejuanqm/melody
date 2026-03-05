package com.melody.runtime.widget

import android.content.Context
import org.json.JSONObject

/**
 * Per-instance widget configuration stored in a dedicated SharedPreferences file.
 * Each widget instance (identified by appWidgetId) stores a flat Map<String, String>
 * containing all data needed for the widget (server URL, token, container ID, etc.).
 */
object WidgetConfigStore {

    private const val PREFS_NAME = "melody_widget_config"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveData(context: Context, appWidgetId: Int, data: Map<String, String>) {
        val json = JSONObject(data)
        prefs(context).edit().putString("widget_$appWidgetId", json.toString()).apply()
    }

    fun getData(context: Context, appWidgetId: Int): Map<String, String>? {
        val raw = prefs(context).getString("widget_$appWidgetId", null) ?: return null
        return try {
            val obj = JSONObject(raw)
            obj.keys().asSequence().associateWith { obj.getString(it) }
        } catch (_: Exception) {
            null
        }
    }

    fun deleteConfig(context: Context, appWidgetId: Int) {
        prefs(context).edit().remove("widget_$appWidgetId").apply()
    }
}
