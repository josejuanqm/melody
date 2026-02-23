package com.melody.runtime.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.SubcomposeAsyncImage
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalAssetBaseURL
import com.melody.runtime.renderer.LocalThemeColors

@Composable
fun MelodyImage(
    definition: ComponentDefinition,
    resolvedSrc: String?,
    resolvedSystemImage: String?
) {
    val themeColors = LocalThemeColors.current
    val assetBaseURL = LocalAssetBaseURL.current
    val style = definition.style
    val tint = style?.color.resolved?.let { parseColor(it, themeColors) }
    val contentScale = when (style?.contentMode?.lowercase()) {
        "fill" -> ContentScale.Crop
        else -> ContentScale.Fit
    }

    val modifier = Modifier.melodyStyle(style)

    val effectiveSrc = run {
        val src = resolvedSrc ?: definition.src.resolved
        if (src != null && src.startsWith("assets/")) {
            if (assetBaseURL != null) {
                "$assetBaseURL/$src"
            } else {
                "file:///android_asset/$src"
            }
        } else {
            src
        }
    }

    when {
        !resolvedSystemImage.isNullOrEmpty() -> {
            SystemImageMapper.Icon(
                sfSymbolName = resolvedSystemImage,
                modifier = modifier,
                tint = tint ?: androidx.compose.ui.graphics.Color.Unspecified
            )
        }
        !effectiveSrc.isNullOrEmpty() -> {
            SubcomposeAsyncImage(
                model = effectiveSrc,
                contentDescription = null,
                contentScale = contentScale,
                modifier = modifier,
                loading = {
                    Box(contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    }
                },
                error = {
                    SystemImageMapper.Icon("photo", tint = androidx.compose.ui.graphics.Color.Gray)
                }
            )
        }
    }
}
