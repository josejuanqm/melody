package com.melody.runtime.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.DirectionAxis
import com.melody.core.schema.Value
import com.melody.core.schema.ViewAlignment
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalIsInFormContext

@Composable
fun MelodyStack(
    definition: ComponentDefinition,
    renderChild: @Composable (ComponentDefinition) -> Unit,
    resolveVisible: (Value<Boolean>?) -> Boolean = { it?.literalValue ?: true },
    dynamicContent: @Composable () -> Unit = {}
) {
    val style = definition.style
    val direction = definition.direction.resolved ?: DirectionAxis.Vertical
    val spacing = (style?.spacing.resolved ?: 0.0).dp
    val children = definition.children ?: emptyList()
    val shouldGrow = definition.shouldGrowToFitParent == true
        && style?.width == null && style?.height == null

    val hasSpacer = children.any {
        it.component.lowercase() == "spacer" && resolveVisible(it.visible)
    }
    val hasAnyPriority = children.any {
        it.component.lowercase() != "spacer" &&
            resolveVisible(it.visible) &&
            (it.style?.layoutPriority.resolved ?: 0.0) > 0
    }

    val needsFill = shouldGrow || LocalIsInFormContext.current ||
        ((hasSpacer || hasAnyPriority) && direction == DirectionAxis.Horizontal)
    val needsFillV = (hasSpacer || hasAnyPriority) && direction == DirectionAxis.Vertical

    val modifier = Modifier.melodyStyle(style)
        .then(if (needsFill) Modifier.fillMaxWidth() else Modifier)
        .then(if (needsFillV) Modifier.fillMaxHeight() else Modifier)
    val align = style?.alignment.resolved

    when (direction) {
        DirectionAxis.Horizontal -> {
            val verticalAlignment = when (align) {
                ViewAlignment.Top -> Alignment.Top
                ViewAlignment.Bottom -> Alignment.Bottom
                else -> Alignment.CenterVertically
            }
            if (definition.lazy == true) {
                LazyRow(
                    modifier = modifier,
                    horizontalArrangement = Arrangement.spacedBy(spacing),
                    verticalAlignment = verticalAlignment
                ) {
                    items(children.size) { i ->
                        RenderLazyChild(children[i], resolveVisible, renderChild)
                    }
                    item { dynamicContent() }
                }
            } else {
                Row(
                    modifier = modifier,
                    horizontalArrangement = Arrangement.spacedBy(spacing),
                    verticalAlignment = verticalAlignment
                ) {
                    for (child in children) {
                        RenderRowChild(child, resolveVisible, renderChild, hasAnyPriority)
                    }
                    dynamicContent()
                }
            }
        }
        DirectionAxis.Stacked -> {
            val contentAlignment = when (align) {
                ViewAlignment.Center -> Alignment.Center
                ViewAlignment.TopLeading, ViewAlignment.TopLeft -> Alignment.TopStart
                ViewAlignment.TopTrailing, ViewAlignment.TopRight -> Alignment.TopEnd
                ViewAlignment.Top -> Alignment.TopCenter
                ViewAlignment.BottomLeading, ViewAlignment.BottomLeft -> Alignment.BottomStart
                ViewAlignment.BottomTrailing, ViewAlignment.BottomRight -> Alignment.BottomEnd
                ViewAlignment.Bottom -> Alignment.BottomCenter
                ViewAlignment.Leading, ViewAlignment.Left -> Alignment.CenterStart
                ViewAlignment.Trailing, ViewAlignment.Right -> Alignment.CenterEnd
                else -> Alignment.TopStart
            }
            Box(
                modifier = modifier,
                contentAlignment = contentAlignment
            ) {
                for (child in children) {
                    RenderBoxChild(child, resolveVisible, renderChild)
                }
                dynamicContent()
            }
        }
        DirectionAxis.Vertical -> {
            val horizontalAlignment = when (align) {
                ViewAlignment.Center -> Alignment.CenterHorizontally
                ViewAlignment.Trailing, ViewAlignment.Right -> Alignment.End
                else -> Alignment.Start
            }
            if (definition.lazy == true) {
                LazyColumn(
                    modifier = modifier,
                    verticalArrangement = Arrangement.spacedBy(spacing),
                    horizontalAlignment = horizontalAlignment
                ) {
                    items(children.size) { i ->
                        RenderLazyChild(children[i], resolveVisible, renderChild)
                    }
                    item { dynamicContent() }
                }
            } else {
                Column(
                    modifier = modifier,
                    verticalArrangement = Arrangement.spacedBy(spacing),
                    horizontalAlignment = horizontalAlignment
                ) {
                    for (child in children) {
                        RenderColumnChild(child, resolveVisible, renderChild, hasAnyPriority)
                    }
                    dynamicContent()
                }
            }
        }
    }
}

@Composable
private fun RowScope.RenderRowChild(
    child: ComponentDefinition,
    resolveVisible: (Value<Boolean>?) -> Boolean,
    renderChild: @Composable (ComponentDefinition) -> Unit,
    hasAnyPriority: Boolean
) {
    if (!resolveVisible(child.visible)) return
    if (child.component.lowercase() == "spacer") {
        Spacer(modifier = Modifier.weight(1f))
        return
    }
    if (hasAnyPriority) {
        val priority = child.style?.layoutPriority.resolved ?: 0.0
        val hasFixedSize = child.style?.width != null || child.style?.height != null
        if (priority > 0 || hasFixedSize) {
            renderChild(child)
        } else {
            Box(modifier = Modifier.weight(1f)) {
                renderChild(child)
            }
        }
    } else {
        renderChild(child)
    }
}

@Composable
private fun ColumnScope.RenderColumnChild(
    child: ComponentDefinition,
    resolveVisible: (Value<Boolean>?) -> Boolean,
    renderChild: @Composable (ComponentDefinition) -> Unit,
    hasAnyPriority: Boolean
) {
    if (!resolveVisible(child.visible)) return
    if (child.component.lowercase() == "spacer") {
        Spacer(modifier = Modifier.weight(1f))
        return
    }
    if (hasAnyPriority) {
        val priority = child.style?.layoutPriority.resolved ?: 0.0
        val hasFixedSize = child.style?.width != null || child.style?.height != null
        if (priority > 0 || hasFixedSize) {
            renderChild(child)
        } else {
            Box(modifier = Modifier.weight(1f)) {
                renderChild(child)
            }
        }
    } else {
        renderChild(child)
    }
}

@Composable
private fun RenderBoxChild(
    child: ComponentDefinition,
    resolveVisible: (Value<Boolean>?) -> Boolean,
    renderChild: @Composable (ComponentDefinition) -> Unit
) {
    if (!resolveVisible(child.visible)) return
    if (child.component.lowercase() == "spacer") {
        Spacer(modifier = Modifier.defaultMinSize(minWidth = 0.dp, minHeight = 0.dp))
        return
    }
    renderChild(child)
}

@Composable
private fun RenderLazyChild(
    child: ComponentDefinition,
    resolveVisible: (Value<Boolean>?) -> Boolean,
    renderChild: @Composable (ComponentDefinition) -> Unit
) {
    if (!resolveVisible(child.visible)) return
    if (child.component.lowercase() == "spacer") {
        Spacer(modifier = Modifier)
        return
    }
    renderChild(child)
}
