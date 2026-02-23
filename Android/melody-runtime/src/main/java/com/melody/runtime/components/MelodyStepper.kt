package com.melody.runtime.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalScreenState

@Composable
fun MelodyStepper(
    definition: ComponentDefinition,
    resolvedLabel: String,
    onChanged: (() -> Unit)? = null
) {
    val screenState = LocalScreenState.current
    val isDisabled = LocalIsDisabled.current
    val stateKey = definition.stateKey
    val minValue = definition.min ?: 0.0
    val maxValue = definition.max ?: 100.0
    val stepValue = definition.step ?: 1.0

    val currentValue = if (stateKey != null) {
        screenState.slot(stateKey).value.numberValue ?: 0.0
    } else {
        0.0
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.melodyStyle(definition.style)
    ) {
        if (resolvedLabel.isNotEmpty()) {
            Text(resolvedLabel, modifier = Modifier.weight(1f))
        }

        IconButton(
            onClick = {
                val newValue = (currentValue - stepValue).coerceAtLeast(minValue)
                if (stateKey != null) {
                    screenState.set(stateKey, LuaValue.NumberVal(newValue))
                }
                onChanged?.invoke()
            },
            enabled = !isDisabled && currentValue > minValue
        ) {
            Icon(Icons.Default.Remove, contentDescription = "Decrease")
        }

        Text(
            text = if (currentValue == currentValue.toLong().toDouble()) {
                currentValue.toLong().toString()
            } else {
                currentValue.toString()
            }
        )

        IconButton(
            onClick = {
                val newValue = (currentValue + stepValue).coerceAtMost(maxValue)
                if (stateKey != null) {
                    screenState.set(stateKey, LuaValue.NumberVal(newValue))
                }
                onChanged?.invoke()
            },
            enabled = !isDisabled && currentValue < maxValue
        ) {
            Icon(Icons.Default.Add, contentDescription = "Increase")
        }
    }
}
