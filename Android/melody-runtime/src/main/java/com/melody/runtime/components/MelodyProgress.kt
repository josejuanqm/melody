package com.melody.runtime.components

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.melody.core.schema.ComponentDefinition

@Composable
fun MelodyProgress(
    definition: ComponentDefinition,
    resolvedValue: String?,
    resolvedLabel: String?
) {
    val progressValue = resolvedValue?.toDoubleOrNull()
    val modifier = Modifier.melodyStyle(definition.style)
    val hasLabel = !resolvedLabel.isNullOrEmpty()

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
    ) {
        if (hasLabel) {
            Text(resolvedLabel!!)
        }
        if (progressValue != null) {
            LinearProgressIndicator(
                progress = { progressValue.toFloat().coerceIn(0f, 1f) }
            )
        } else {
            CircularProgressIndicator()
        }
    }
}
