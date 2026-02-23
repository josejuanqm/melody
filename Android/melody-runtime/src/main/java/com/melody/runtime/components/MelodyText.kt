package com.melody.runtime.components

import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.ViewAlignment
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodyText(
    definition: ComponentDefinition,
    resolvedText: String
) {
    val themeColors = LocalThemeColors.current
    val style = definition.style

    val fontSize = (style?.fontSize.resolved ?: 16.0).sp
    val fontWeight = resolveFontWeight(style?.fontWeight)
    val fontFamily = resolveFontFamily(style?.fontDesign)
    val color = style?.color.resolved?.let { parseColor(it, themeColors) }
    val textAlign = when (style?.alignment.resolved) {
        ViewAlignment.Center -> TextAlign.Center
        ViewAlignment.Trailing, ViewAlignment.Right -> TextAlign.End
        else -> TextAlign.Start
    }
    val maxLines = style?.lineLimit.resolved ?: Int.MAX_VALUE

    Text(
        text = resolvedText,
        fontSize = fontSize,
        fontWeight = fontWeight,
        fontFamily = fontFamily,
        color = color ?: androidx.compose.ui.graphics.Color.Unspecified,
        textAlign = textAlign,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.melodyStyle(style)
    )
}
