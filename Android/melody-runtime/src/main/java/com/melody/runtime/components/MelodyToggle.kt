package com.melody.runtime.components

import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalScreenState
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodyToggle(definition: ComponentDefinition, onChanged: (() -> Unit)? = null) {
    val screenState = LocalScreenState.current
    val isDisabled = LocalIsDisabled.current
    val themeColors = LocalThemeColors.current
    val style = definition.style
    val stateKey = definition.stateKey
    val label = definition.label.resolved ?: ""
    val tintColor = style?.color.resolved?.let { parseColor(it, themeColors) }

    val isOn = if (stateKey != null) {
        screenState.slot(stateKey).value.boolValue ?: false
    } else {
        false
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.melodyStyle(style)
    ) {
        if (label.isNotEmpty()) {
            Text(label)
            Spacer(modifier = Modifier.width(8.dp))
        }
        Switch(
            checked = isOn,
            enabled = !isDisabled,
            onCheckedChange = { newValue ->
                if (stateKey != null) {
                    screenState.set(stateKey, LuaValue.BoolVal(newValue))
                }
                onChanged?.invoke()
            },
            colors = if (tintColor != null) {
                SwitchDefaults.colors(checkedTrackColor = tintColor)
            } else {
                SwitchDefaults.colors()
            }
        )
    }
}
