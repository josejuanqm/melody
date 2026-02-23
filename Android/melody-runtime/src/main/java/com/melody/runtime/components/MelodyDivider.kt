package com.melody.runtime.components

import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodyDivider(definition: ComponentDefinition) {
    val themeColors = LocalThemeColors.current
    val color = definition.style?.color.resolved?.let { parseColor(it, themeColors) }

    HorizontalDivider(
        modifier = Modifier.melodyStyle(definition.style),
        color = color ?: androidx.compose.ui.graphics.Color.Unspecified
    )
}
