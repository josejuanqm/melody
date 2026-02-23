package com.melody.runtime.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodyMenu(
    definition: ComponentDefinition,
    resolvedLabel: String,
    resolvedSystemImage: String?,
    content: @Composable () -> Unit
) {
    val themeColors = LocalThemeColors.current
    val isDisabled = LocalIsDisabled.current
    var expanded by remember { mutableStateOf(false) }
    val hasIcon = !resolvedSystemImage.isNullOrEmpty()
    val textColor = definition.style?.color.resolved?.let { parseColor(it, themeColors) }

    Box(modifier = Modifier.melodyStyle(definition.style)) {
        TextButton(onClick = { expanded = true }, enabled = !isDisabled) {
            if (hasIcon && resolvedLabel.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    SystemImageMapper.Icon(
                        resolvedSystemImage!!,
                        tint = textColor ?: LocalContentColor.current
                    )
                    Text(resolvedLabel, color = textColor ?: androidx.compose.ui.graphics.Color.Unspecified)
                }
            } else if (hasIcon) {
                SystemImageMapper.Icon(
                    resolvedSystemImage!!,
                    tint = textColor ?: LocalContentColor.current
                )
            } else {
                Text(resolvedLabel, color = textColor ?: androidx.compose.ui.graphics.Color.Unspecified)
            }
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            content()
        }
    }
}
