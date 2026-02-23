package com.melody.runtime.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentStyle
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalThemeColors

/**
 * Extension function that applies ComponentStyle properties as Compose modifiers.
 * Port of iOS StyleModifier / melodyStyle().
 */
@Composable
fun Modifier.melodyStyle(style: ComponentStyle?, skipPadding: Boolean = false): Modifier {
    if (style == null) return this
    val themeColors = LocalThemeColors.current

    var mod = this

    val mTop = (style.marginTop.resolved ?: style.marginVertical.resolved ?: style.margin.resolved ?: 0.0).dp
    val mBottom = (style.marginBottom.resolved ?: style.marginVertical.resolved ?: style.margin.resolved ?: 0.0).dp
    val mStart = (style.marginLeft.resolved ?: style.marginHorizontal.resolved ?: style.margin.resolved ?: 0.0).dp
    val mEnd = (style.marginRight.resolved ?: style.marginHorizontal.resolved ?: style.margin.resolved ?: 0.0).dp
    if (mTop.value > 0 || mBottom.value > 0 || mStart.value > 0 || mEnd.value > 0) {
        mod = mod.padding(start = mStart, top = mTop, end = mEnd, bottom = mBottom)
    }

    val width = style.width.resolved?.let { if (it < 0) null else it.dp }
    val height = style.height.resolved?.let { if (it < 0) null else it.dp }
    val fillWidth = style.width.resolved?.let { it < 0 } == true
    val fillHeight = style.height.resolved?.let { it < 0 } == true

    if (width != null || height != null) {
        mod = mod.then(
            if (width != null && height != null) Modifier.size(width, height)
            else if (width != null) Modifier.width(width)
            else Modifier.height(height!!)
        )
    }
    if (fillWidth) mod = mod.fillMaxWidth()
    if (fillHeight) mod = mod.fillMaxHeight()

    val fillMaxW = style.maxWidth.resolved?.let { it < 0 } == true
    val fillMaxH = style.maxHeight.resolved?.let { it < 0 } == true
    if (fillMaxW) mod = mod.fillMaxWidth()
    if (fillMaxH) mod = mod.fillMaxHeight()

    val minW = style.minWidth.resolved?.let { if (it < 0) null else it.dp }
    val minH = style.minHeight.resolved?.let { if (it < 0) null else it.dp }
    val maxW = if (fillMaxW) null else style.maxWidth.resolved?.let { if (it > 0) it.dp else null }
    val maxH = if (fillMaxH) null else style.maxHeight.resolved?.let { if (it > 0) it.dp else null }

    // When maxWidth/maxHeight is set to a positive value, expand to fill parent
    // up to that constraint — matching iOS .frame(maxWidth:) behavior
    if (maxW != null && width == null && !fillWidth) mod = mod.fillMaxWidth()
    if (maxH != null && height == null && !fillHeight) mod = mod.fillMaxHeight()

    if (minW != null || minH != null || maxW != null || maxH != null) {
        mod = mod.sizeIn(
            minWidth = minW ?: Dp.Unspecified,
            minHeight = minH ?: Dp.Unspecified,
            maxWidth = maxW ?: Dp.Unspecified,
            maxHeight = maxH ?: Dp.Unspecified
        )
    }

    val cornerRadius = (style.cornerRadius.resolved ?: style.borderRadius.resolved ?: 0.0).dp
    val shape = if (cornerRadius.value > 0) RoundedCornerShape(cornerRadius) else RoundedCornerShape(0.dp)

    style.shadow?.let { shadow ->
        val shadowColor = shadow.color?.let { parseColor(it, themeColors) } ?: Color.Black.copy(alpha = 0.2f)
        val blur = (shadow.blur ?: 0.0).dp
        if (blur.value > 0) {
            mod = mod.shadow(elevation = blur / 2, shape = shape)
        }
    }

    style.backgroundColor.resolved?.let { bg ->
        val bgColor = parseColor(bg, themeColors)
        mod = mod.background(bgColor, shape)
    }

    if (cornerRadius.value > 0) {
        mod = mod.clip(shape)
    }

    style.borderWidth.resolved?.let { bw ->
        if (bw > 0) {
            val borderColor = parseColor(style.borderColor.resolved ?: "#000000", themeColors)
            mod = mod.border(bw.dp, borderColor, shape)
        }
    }

    style.opacity.resolved?.let { mod = mod.alpha(it.toFloat()) }

    style.scale.resolved?.let { mod = mod.scale(it.toFloat()) }

    style.rotation.resolved?.let { mod = mod.rotate(it.toFloat()) }

    if (!skipPadding) {
        val pTop = (style.paddingTop.resolved ?: style.paddingVertical.resolved ?: style.padding.resolved ?: 0.0).dp
        val pBottom = (style.paddingBottom.resolved ?: style.paddingVertical.resolved ?: style.padding.resolved ?: 0.0).dp
        val pStart = (style.paddingLeft.resolved ?: style.paddingHorizontal.resolved ?: style.padding.resolved ?: 0.0).dp
        val pEnd = (style.paddingRight.resolved ?: style.paddingHorizontal.resolved ?: style.padding.resolved ?: 0.0).dp
        if (pTop.value > 0 || pBottom.value > 0 || pStart.value > 0 || pEnd.value > 0) {
            mod = mod.padding(start = pStart, top = pTop, end = pEnd, bottom = pBottom)
        }
    }

    return mod
}

/** Parse a hex color string or theme reference */
fun parseColorOrNil(value: String, themeColors: Map<String, String> = emptyMap()): Color? {
    val hex = resolveColorHexOrNil(value, themeColors)
    return hex?.let { hexToColor(it) }
}

fun parseColor(value: String, themeColors: Map<String, String> = emptyMap()): Color {
    val hex = resolveColorHex(value, themeColors)
    return hexToColor(hex)
}

fun resolveColorHexOrNil(value: String, themeColors: Map<String, String>): String? {
    if (value.startsWith("theme.")) {
        val key = value.removePrefix("theme.")
        return themeColors[key]
    }
    return null
}

fun resolveColorHex(value: String, themeColors: Map<String, String>): String {
    if (value.startsWith("theme.")) {
        val key = value.removePrefix("theme.")
        return themeColors[key] ?: value
    }
    return value
}

fun hexToColor(hex: String): Color {
    val cleaned = hex.removePrefix("#")
    return try {
        when (cleaned.length) {
            6 -> {
                val value = cleaned.toLong(16)
                Color(
                    red = ((value shr 16) and 0xFF) / 255f,
                    green = ((value shr 8) and 0xFF) / 255f,
                    blue = (value and 0xFF) / 255f
                )
            }
            8 -> {
                val value = cleaned.toLong(16)
                Color(
                    red = ((value shr 24) and 0xFF) / 255f,
                    green = ((value shr 16) and 0xFF) / 255f,
                    blue = ((value shr 8) and 0xFF) / 255f,
                    alpha = (value and 0xFF) / 255f
                )
            }
            else -> Color.Transparent
        }
    } catch (_: Exception) {
        Color.Transparent
    }
}

fun resolveFontWeight(weight: String?): androidx.compose.ui.text.font.FontWeight {
    return when (weight?.lowercase()) {
        "bold" -> androidx.compose.ui.text.font.FontWeight.Bold
        "semibold" -> androidx.compose.ui.text.font.FontWeight.SemiBold
        "medium" -> androidx.compose.ui.text.font.FontWeight.Medium
        "light" -> androidx.compose.ui.text.font.FontWeight.Light
        "thin" -> androidx.compose.ui.text.font.FontWeight.Thin
        "heavy", "black" -> androidx.compose.ui.text.font.FontWeight.Black
        "ultralight" -> androidx.compose.ui.text.font.FontWeight.ExtraLight
        else -> androidx.compose.ui.text.font.FontWeight.Normal
    }
}

fun resolveFontFamily(design: String?): androidx.compose.ui.text.font.FontFamily? {
    return when (design?.lowercase()) {
        "monospaced", "mono" -> androidx.compose.ui.text.font.FontFamily.Monospace
        "serif" -> androidx.compose.ui.text.font.FontFamily.Serif
        else -> null
    }
}
