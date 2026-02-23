package com.melody.runtime.components

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodyLink(
    definition: ComponentDefinition,
    resolvedLabel: String,
    resolvedURL: String,
    resolvedSystemImage: String?
) {
    val context = LocalContext.current
    val isDisabled = LocalIsDisabled.current
    val themeColors = LocalThemeColors.current
    val textColor = definition.style?.color.resolved?.let { parseColor(it, themeColors) }
    val hasIcon = !resolvedSystemImage.isNullOrEmpty()

    TextButton(
        onClick = {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(resolvedURL))
                context.startActivity(intent)
            } catch (_: Exception) {}
        },
        enabled = !isDisabled,
        modifier = Modifier.melodyStyle(definition.style)
    ) {
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
}
