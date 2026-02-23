package com.melody.runtime.components

import androidx.compose.material3.Slider
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.melody.core.schema.ComponentDefinition
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalScreenState

@Composable
fun MelodySlider(definition: ComponentDefinition, onChanged: (() -> Unit)? = null) {
    val screenState = LocalScreenState.current
    val isDisabled = LocalIsDisabled.current
    val stateKey = definition.stateKey
    val minValue = (definition.min ?: 0.0).toFloat()
    val maxValue = (definition.max ?: 1.0).toFloat()
    val stepValue = definition.step?.toFloat() ?: 0f

    val currentValue = if (stateKey != null) {
        (screenState.slot(stateKey).value.numberValue ?: 0.0).toFloat()
    } else {
        0f
    }

    Slider(
        value = currentValue.coerceIn(minValue, maxValue),
        enabled = !isDisabled,
        onValueChange = { newValue ->
            if (stateKey != null) {
                screenState.set(stateKey, LuaValue.NumberVal(newValue.toDouble()))
            }
            onChanged?.invoke()
        },
        valueRange = minValue..maxValue,
        steps = if (stepValue > 0f) {
            ((maxValue - minValue) / stepValue).toInt() - 1
        } else {
            0
        },
        modifier = Modifier.melodyStyle(definition.style)
    )
}
