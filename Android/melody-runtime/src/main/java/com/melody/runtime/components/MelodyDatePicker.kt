package com.melody.runtime.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalScreenState
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MelodyDatePicker(definition: ComponentDefinition, onChanged: (() -> Unit)? = null) {
    val screenState = LocalScreenState.current
    val isDisabled = LocalIsDisabled.current
    val stateKey = definition.stateKey
    val label = definition.label.resolved ?: ""
    var showPicker by remember { mutableStateOf(false) }

    val currentValue = if (stateKey != null) {
        screenState.slot(stateKey).value.stringValue ?: ""
    } else {
        ""
    }

    val displayText = if (currentValue.isNotEmpty()) {
        formatDisplayDate(currentValue)
    } else {
        label.ifEmpty { "Select date" }
    }

    OutlinedButton(
        onClick = { showPicker = true },
        enabled = !isDisabled,
        modifier = Modifier.melodyStyle(definition.style)
    ) {
        Text(displayText)
    }

    if (showPicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = parseISO8601(currentValue)?.time
        )

        DatePickerDialog(
            onDismissRequest = { showPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        val date = Date(millis)
                        val iso = formatISO8601(date)
                        if (stateKey != null) {
                            screenState.set(stateKey, LuaValue.StringVal(iso))
                        }
                        onChanged?.invoke()
                    }
                    showPicker = false
                }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showPicker = false }) {
                    Text("Cancel")
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }
}

private fun parseISO8601(string: String): Date? {
    if (string.isEmpty()) return null
    val formats = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd"
    )
    for (format in formats) {
        try {
            val sdf = SimpleDateFormat(format, Locale.US)
            sdf.timeZone = TimeZone.getTimeZone("UTC")
            return sdf.parse(string)
        } catch (_: Exception) {}
    }
    return null
}

private fun formatISO8601(date: Date): String {
    val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
    sdf.timeZone = TimeZone.getTimeZone("UTC")
    return sdf.format(date)
}

private fun formatDisplayDate(isoString: String): String {
    val date = parseISO8601(isoString) ?: return isoString
    val sdf = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
    return sdf.format(date)
}
