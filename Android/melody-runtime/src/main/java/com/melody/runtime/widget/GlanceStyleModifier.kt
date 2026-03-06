package com.melody.runtime.widget

import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.background
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.width
import androidx.glance.layout.size
import androidx.glance.appwidget.cornerRadius
import androidx.glance.unit.ColorProvider
import com.melody.core.schema.ComponentStyle
import com.melody.core.schema.resolved
import com.melody.runtime.components.hexToColor
import com.melody.runtime.components.resolveColorHex
import com.melody.runtime.components.resolveColorHexOrNil

/**
 * Builds a GlanceModifier from a ComponentStyle.
 * Only applies properties that Glance supports:
 * width, height, padding, backgroundColor, cornerRadius.
 *
 * Skipped silently: opacity, scale, rotation, shadow, border, aspectRatio, margin.
 */
fun GlanceModifier.glanceStyle(
    style: ComponentStyle?,
    themeColors: Map<String, String> = emptyMap()
): GlanceModifier {
    if (style == null) return this
    var mod = this

    // Sizing
    val w = style.width.resolved?.let { if (it < 0) null else it.dp }
    val h = style.height.resolved?.let { if (it < 0) null else it.dp }
    val fillW = (style.width.resolved?.let { it < 0 } == true) || (style.maxWidth.resolved?.let { it < 0 } == true)
    val fillH = (style.height.resolved?.let { it < 0 } == true) || (style.maxHeight.resolved?.let { it < 0 } == true)

    if (w != null && h != null) {
        mod = mod.then(GlanceModifier.size(w, h))
    } else if (w != null) {
        mod = mod.then(GlanceModifier.width(w))
    } else if (h != null) {
        mod = mod.then(GlanceModifier.height(h))
    }
    if (fillW) mod = mod.then(GlanceModifier.fillMaxWidth())
    if (fillH) mod = mod.then(GlanceModifier.fillMaxHeight())

    // Padding (same cascade as StyleModifier)
    val pTop = (style.paddingTop.resolved ?: style.paddingVertical.resolved ?: style.padding.resolved ?: 0.0).dp
    val pBottom = (style.paddingBottom.resolved ?: style.paddingVertical.resolved ?: style.padding.resolved ?: 0.0).dp
    val pStart = (style.paddingLeft.resolved ?: style.paddingHorizontal.resolved ?: style.padding.resolved ?: 0.0).dp
    val pEnd = (style.paddingRight.resolved ?: style.paddingHorizontal.resolved ?: style.padding.resolved ?: 0.0).dp
    if (pTop.value > 0 || pBottom.value > 0 || pStart.value > 0 || pEnd.value > 0) {
        mod = mod.then(GlanceModifier.padding(start = pStart, top = pTop, end = pEnd, bottom = pBottom))
    }

    // Corner radius
    val cr = (style.cornerRadius.resolved ?: style.borderRadius.resolved ?: 0.0).dp
    if (cr.value > 0) {
        mod = mod.then(GlanceModifier.cornerRadius(cr))
    }

    // Background color
    style.backgroundColor.resolved?.let { bg ->
        val hex = resolveColorHex(bg, themeColors)
        val color = hexToColor(hex)
        mod = mod.then(GlanceModifier.background(ColorProvider(color)))
    }

    return mod
}

/**
 * Resolves a color string (hex or theme reference) to an Android Color for Glance.
 */
fun resolveGlanceColor(
    value: String?,
    themeColors: Map<String, String>,
    default: androidx.compose.ui.graphics.Color? = null
): androidx.compose.ui.graphics.Color? {
    if (value == null) return default
    // For theme references, use resolveColorHexOrNil so unresolvable refs return the default
    if (value.startsWith("theme.")) {
        val hex = resolveColorHexOrNil(value, themeColors) ?: return default
        return hexToColor(hex)
    }
    return hexToColor(resolveColorHex(value, themeColors))
}
