package com.melody.runtime.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.runtime.renderer.ComponentRenderer
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodySection(
    definition: ComponentDefinition,
    resolvedLabel: String,
    resolvedFooter: String,
    headerContent: List<ComponentDefinition>?,
    footerComponents: List<ComponentDefinition>?,
    content: @Composable () -> Unit
) {
    val themeColors = LocalThemeColors.current
    val textColor = parseColorOrNil("theme.textPrimary", themeColors) ?: MaterialTheme.colorScheme.onSurface

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .then(Modifier.melodyStyle(definition.style))
    ) {
        if (!headerContent.isNullOrEmpty()) {
            Box(
                modifier = Modifier.padding(
                    start = 16.dp,
                    end = 16.dp,
                    bottom = 8.dp,
                    top = 12.dp
                )
            ) {
                ComponentRenderer(components = headerContent)
            }
        } else if (resolvedLabel.isNotEmpty()) {
            Text(
                text = resolvedLabel.uppercase(),
                style = MaterialTheme.typography.labelMedium,
                color = textColor.copy(alpha = 0.8f),
                modifier = Modifier.padding(
                    start = 16.dp,
                    end = 16.dp,
                    bottom = 8.dp,
                    top = 12.dp
                )
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        ) {
            content()
        }

        if (!footerComponents.isNullOrEmpty()) {
            Box(
                modifier = Modifier.padding(
                    start = 16.dp,
                    end = 16.dp,
                    top = 6.dp,
                    bottom = 4.dp
                )
            ) {
                ComponentRenderer(components = footerComponents)
            }
        } else if (resolvedFooter.isNotEmpty()) {
            Text(
                text = resolvedFooter,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(
                    start = 16.dp,
                    end = 16.dp,
                    top = 6.dp,
                    bottom = 4.dp
                )
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(vertical = 8.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )
    }
}
