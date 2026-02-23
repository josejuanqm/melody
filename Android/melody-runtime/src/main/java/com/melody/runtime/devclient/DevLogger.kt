package com.melody.runtime.devclient

import androidx.compose.runtime.mutableStateListOf
import java.util.Date
import java.util.UUID

data class LogEntry(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Date = Date(),
    val message: String,
    val source: String
)

object DevLogger {
    val entries = mutableStateListOf<LogEntry>()
    private const val MAX_ENTRIES = 500

    fun log(message: String, source: String = "system") {
        entries.add(LogEntry(message = message, source = source))
        if (entries.size > MAX_ENTRIES) {
            entries.removeRange(0, entries.size - MAX_ENTRIES)
        }
    }

    fun clear() {
        entries.clear()
    }
}
