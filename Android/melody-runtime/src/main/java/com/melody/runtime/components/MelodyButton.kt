package com.melody.runtime.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.ViewAlignment
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodyButton(
    definition: ComponentDefinition,
    resolvedLabel: String,
    resolvedSystemImage: String?,
    onTap: () -> Unit
) {
    val themeColors = LocalThemeColors.current
    val isDisabled = LocalIsDisabled.current
    val style = definition.style
    val hasLabel = resolvedLabel.isNotEmpty()
    val hasIcon = !resolvedSystemImage.isNullOrEmpty()
    val textColor = style?.color.resolved?.let { parseColor(it, themeColors) }
        ?: MaterialTheme.colorScheme.primary
    val hasBg = style?.backgroundColor.resolved != null
    val fontSize = (style?.fontSize.resolved ?: 16.0).sp
    val fontWeight = resolveFontWeight(style?.fontWeight)

    val alignment = when (style?.alignment.resolved) {
        ViewAlignment.Leading, ViewAlignment.Left -> Alignment.CenterStart
        ViewAlignment.Trailing, ViewAlignment.Right -> Alignment.CenterEnd
        else -> Alignment.Center
    }
    val textAlign = when (style?.alignment.resolved) {
        ViewAlignment.Leading, ViewAlignment.Left -> TextAlign.Start
        ViewAlignment.Trailing, ViewAlignment.Right -> TextAlign.End
        else -> TextAlign.Center
    }

    Box(
        modifier = Modifier
            .then(if (hasBg) Modifier.fillMaxWidth() else Modifier)
            .melodyStyle(style)
            .clickable(enabled = !isDisabled, onClick = onTap),
        contentAlignment = alignment
    ) {
        if (hasIcon && hasLabel) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                SystemImageMapper.Icon(resolvedSystemImage!!, tint = textColor)
                Text(
                    resolvedLabel,
                    color = textColor,
                    fontSize = fontSize,
                    fontWeight = fontWeight,
                    textAlign = textAlign
                )
            }
        } else if (hasIcon) {
            SystemImageMapper.Icon(resolvedSystemImage!!, tint = textColor)
        } else {
            Text(
                resolvedLabel,
                color = textColor,
                fontSize = fontSize,
                fontWeight = fontWeight,
                textAlign = textAlign,
                modifier = if (hasBg) Modifier.fillMaxWidth() else Modifier
            )
        }
    }
}
