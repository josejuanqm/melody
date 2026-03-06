package com.melody.runtime.renderer

import WidgetFamily
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity as appWidgetActionStartActivity
import androidx.glance.background
import androidx.glance.layout.*
import androidx.glance.text.FontWeight as GlanceFontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.CircularProgressIndicator
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.ViewAlignment
import com.melody.core.schema.resolved
import com.melody.runtime.widget.glanceStyle
import com.melody.runtime.widget.resolveGlanceColor

/**
 * Renders a list of pre-resolved ComponentDefinitions using Glance composables.
 * This is a separate renderer from ComponentRenderer because:
 * - Glance uses `androidx.glance.*` composables, not `androidx.compose.*`
 * - No ScreenState, LuaVM, or ExpressionResolver — all values are pre-resolved literals
 * - Widget component subset only: text, stack, image, spacer, divider, button, progress
 */
@Composable
fun GlanceComponentRenderer(
    components: List<ComponentDefinition>,
    themeColors: Map<String, String>
) {
    Box(modifier = GlanceModifier.padding(16.dp)) {
        for (component in components) {
            GlanceComponent(component, themeColors)
        }
    }
}

@Composable
private fun GlanceComponent(
    def: ComponentDefinition,
    themeColors: Map<String, String>
) {
    when (def.component.lowercase()) {
        "text" -> GlanceText(def, themeColors)
        "stack" -> GlanceStack(def, themeColors)
        "image" -> GlanceImage(def, themeColors)
        "button" -> GlanceButton(def, themeColors)
        "spacer" -> Spacer()
        "divider" -> GlanceDivider(def, themeColors)
        "progress" -> GlanceProgress(def, themeColors)
    }
}

// -- Text --

@Composable
private fun GlanceText(def: ComponentDefinition, themeColors: Map<String, String>) {
    val text = def.text?.literalValue ?: return
    val style = def.style

    val textColor = style?.color.resolved?.let {
        resolveGlanceColor(it, themeColors, null)
    }

    val fontSize = style?.fontSize.resolved?.sp
    val fontWeight = style?.fontWeight?.let { resolveGlanceFontWeight(it) }
    val maxLines = style?.lineLimit.resolved

    val textStyle = TextStyle(
        color = textColor?.let { ColorProvider(it) } ?: ColorProvider(Color.Black),
        fontSize = fontSize,
        fontWeight = fontWeight
    )

    Text(
        text = text,
        style = textStyle,
        maxLines = maxLines ?: Int.MAX_VALUE,
        modifier = GlanceModifier.glanceStyle(style, themeColors)
    )
}

// -- Stack (Row / Column / Box) --

@Composable
private fun GlanceStack(def: ComponentDefinition, themeColors: Map<String, String>) {
    val direction = def.direction?.literalValue?.value?.lowercase()
    val modifier = GlanceModifier.glanceStyle(def.style, themeColors)
    val children = def.children ?: emptyList()
    val alignment = def.style?.alignment?.literalValue

    when (direction) {
        "horizontal" -> {
            Row(
                modifier = modifier,
                verticalAlignment = resolveGlanceVerticalAlignment(alignment)
            ) {
                for (child in children) {
                    if (child.component.lowercase() == "spacer") {
                        Spacer(modifier = GlanceModifier.defaultWeight())
                    } else {
                        GlanceComponent(child, themeColors)
                    }
                }
            }
        }
        "z" -> {
            Box(
                modifier = modifier,
                contentAlignment = resolveGlanceBoxAlignment(alignment)
            ) {
                for (child in children) {
                    GlanceComponent(child, themeColors)
                }
            }
        }
        else -> {
            Column(
                modifier = modifier,
                horizontalAlignment = resolveGlanceHorizontalAlignment(alignment)
            ) {
                for (child in children) {
                    if (child.component.lowercase() == "spacer") {
                        Spacer(modifier = GlanceModifier.defaultWeight())
                    } else {
                        GlanceComponent(child, themeColors)
                    }
                }
            }
        }
    }
}

// -- Image --

@Composable
private fun GlanceImage(def: ComponentDefinition, themeColors: Map<String, String>) {
    val modifier = GlanceModifier.glanceStyle(def.style, themeColors)
    val systemImage = def.systemImage?.literalValue

    val resId = systemImage?.let { resolveSystemDrawable(it) }
    if (resId != null) {
        val tint = def.style?.color.resolved?.let {
            resolveGlanceColor(it, themeColors, null)
        }
        Image(
            provider = ImageProvider(resId),
            contentDescription = systemImage,
            modifier = modifier,
            colorFilter = tint?.let { ColorFilter.tint(ColorProvider(it)) }
        )
    } else {
        Box(modifier = modifier) {}
    }
}

private fun resolveSystemDrawable(name: String): Int? {
    val mapped = SYSTEM_IMAGE_MAP[name]
    if (mapped != null) return mapped
    return try {
        val androidName = name
            .replace(".", "_")
            .replace("-", "_")
            .lowercase()
        val id = android.R.drawable::class.java.getField(androidName).getInt(null)
        if (id != 0) id else null
    } catch (_: Exception) {
        null
    }
}

private val SYSTEM_IMAGE_MAP = mapOf(
    "play.fill" to android.R.drawable.ic_media_play,
    "play.circle.fill" to android.R.drawable.ic_media_play,
    "pause.fill" to android.R.drawable.ic_media_pause,
    "pause.circle.fill" to android.R.drawable.ic_media_pause,
    "stop.fill" to android.R.drawable.ic_delete,
    "stop.circle.fill" to android.R.drawable.ic_delete,
    "arrow.clockwise" to android.R.drawable.ic_popup_sync,
    "xmark" to android.R.drawable.ic_menu_close_clear_cancel,
    "checkmark" to android.R.drawable.checkbox_on_background,
    "info.circle" to android.R.drawable.ic_menu_info_details,
    "gear" to android.R.drawable.ic_menu_preferences,
    "star.fill" to android.R.drawable.btn_star_big_on,
    "star" to android.R.drawable.btn_star_big_off,
    "magnifyingglass" to android.R.drawable.ic_menu_search,
    "plus" to android.R.drawable.ic_menu_add,
    "trash" to android.R.drawable.ic_menu_delete,
    "pencil" to android.R.drawable.ic_menu_edit,
    "square.and.arrow.up" to android.R.drawable.ic_menu_share,
)

// -- Button --

@Composable
private fun GlanceButton(def: ComponentDefinition, themeColors: Map<String, String>) {
    val label = def.label?.literalValue ?: def.text?.literalValue ?: ""
    val link = def.url?.literalValue ?: def.onTap
    val modifier = GlanceModifier.glanceStyle(def.style, themeColors)

    val bgColor = def.style?.backgroundColor.resolved?.let {
        resolveGlanceColor(it, themeColors, null)
    }
    val textColor = def.style?.color.resolved?.let {
        resolveGlanceColor(it, themeColors, Color.White)
    } ?: Color.White

    val buttonModifier = if (link != null) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link))
        modifier.then(GlanceModifier.clickable(appWidgetActionStartActivity(intent)))
    } else {
        modifier
    }

    val finalModifier = if (bgColor != null) {
        buttonModifier.then(GlanceModifier.background(ColorProvider(bgColor)))
    } else {
        buttonModifier
    }

    Box(
        modifier = finalModifier.then(
            GlanceModifier.padding(horizontal = 16.dp, vertical = 8.dp)
        ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = TextStyle(
                color = ColorProvider(textColor),
                fontWeight = GlanceFontWeight.Medium
            )
        )
    }
}

// -- Divider --

@Composable
private fun GlanceDivider(def: ComponentDefinition, themeColors: Map<String, String>) {
    val color = def.style?.color.resolved?.let {
        resolveGlanceColor(it, themeColors, Color.LightGray) ?: Color.LightGray
    } ?: Color.LightGray

    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(1.dp)
            .background(ColorProvider(color))
    ) {}
}

// -- Progress --

@Composable
private fun GlanceProgress(def: ComponentDefinition, themeColors: Map<String, String>) {
    val valueStr = def.value?.literalValue
    val progress = valueStr?.toFloatOrNull()

    if (progress != null) {
        // Determinate — linear progress bar
        LinearProgressIndicator(
            progress = progress.coerceIn(0f, 1f),
            modifier = GlanceModifier.glanceStyle(def.style, themeColors).fillMaxWidth()
        )
    } else {
        // Indeterminate — circular spinner
        CircularProgressIndicator(
            modifier = GlanceModifier.glanceStyle(def.style, themeColors)
        )
    }
}

// -- Helpers --

/**
 * Maps a widget size to a WidgetFamily for layout selection.
 */
fun sizeToFamily(size: DpSize): WidgetFamily {
    return when {
        size.width >= 250.dp && size.height >= 250.dp -> WidgetFamily.Large
        size.width >= 250.dp -> WidgetFamily.Medium
        else -> WidgetFamily.Small
    }
}

/**
 * Loads theme colors from SharedPreferences or returns defaults.
 * Widget process doesn't have access to the full app theme, so we read
 * from the same SharedPreferences that the app writes to.
 */
fun loadThemeColors(context: android.content.Context): Map<String, String> {
    val prefs = context.getSharedPreferences("melody_theme", android.content.Context.MODE_PRIVATE)
    val result = mutableMapOf<String, String>()
    prefs.all.forEach { (key, value) ->
        if (value is String) {
            result[key] = value
        }
    }
    return result
}

private fun resolveGlanceFontWeight(weight: String): GlanceFontWeight {
    return when (weight.lowercase()) {
        "bold" -> GlanceFontWeight.Bold
        "medium" -> GlanceFontWeight.Medium
        else -> GlanceFontWeight.Normal
    }
}

// -- Alignment Helpers --

private fun resolveGlanceVerticalAlignment(alignment: ViewAlignment?): Alignment.Vertical {
    return when (alignment) {
        ViewAlignment.Top, ViewAlignment.TopLeading, ViewAlignment.TopLeft,
        ViewAlignment.TopTrailing, ViewAlignment.TopRight -> Alignment.Top
        ViewAlignment.Bottom, ViewAlignment.BottomLeading, ViewAlignment.BottomLeft,
        ViewAlignment.BottomTrailing, ViewAlignment.BottomRight -> Alignment.Bottom
        else -> Alignment.CenterVertically
    }
}

private fun resolveGlanceHorizontalAlignment(alignment: ViewAlignment?): Alignment.Horizontal {
    return when (alignment) {
        ViewAlignment.Leading, ViewAlignment.Left, ViewAlignment.TopLeading,
        ViewAlignment.TopLeft, ViewAlignment.BottomLeading, ViewAlignment.BottomLeft -> Alignment.Start
        ViewAlignment.Trailing, ViewAlignment.Right, ViewAlignment.TopTrailing,
        ViewAlignment.TopRight, ViewAlignment.BottomTrailing, ViewAlignment.BottomRight -> Alignment.End
        else -> Alignment.CenterHorizontally
    }
}

private fun resolveGlanceBoxAlignment(alignment: ViewAlignment?): Alignment {
    return when (alignment) {
        ViewAlignment.Center -> Alignment.Center
        ViewAlignment.Top -> Alignment.TopCenter
        ViewAlignment.Bottom -> Alignment.BottomCenter
        ViewAlignment.Leading, ViewAlignment.Left -> Alignment.CenterStart
        ViewAlignment.Trailing, ViewAlignment.Right -> Alignment.CenterEnd
        ViewAlignment.TopLeading, ViewAlignment.TopLeft -> Alignment.TopStart
        ViewAlignment.TopTrailing, ViewAlignment.TopRight -> Alignment.TopEnd
        ViewAlignment.BottomLeading, ViewAlignment.BottomLeft -> Alignment.BottomStart
        ViewAlignment.BottomTrailing, ViewAlignment.BottomRight -> Alignment.BottomEnd
        else -> Alignment.Center
    }
}
