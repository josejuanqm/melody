package com.melody.runtime.renderer

import android.util.Log
import androidx.compose.animation.*
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.melody.core.schema.*
import com.melody.runtime.components.*
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.state.BindingExtractor

val LocalIsInFormContext = compositionLocalOf { false }

val LocalIsDisabled = compositionLocalOf { false }

/**
 * Renders a component tree from ComponentDefinitions.
 * Port of iOS ComponentRenderer.swift.
 */
@Composable
fun ComponentRenderer(components: List<ComponentDefinition>) {
    for (component in components) {
        BoundComponentView(definition = component)
    }
}

/**
 * Observes only the state keys referenced by this component,
 * then renders the component.
 */
@Composable
fun BoundComponentView(definition: ComponentDefinition) {
    val screenState = LocalScreenState.current
    val luaVM = LocalLuaVM.current
    val localState = LocalLocalState.current
    val customComponents = LocalCustomComponents.current
    val componentProps = LocalComponentProps.current

    val bindings = remember(definition) { BindingExtractor.bindings(definition) }
    for (key in bindings.stateKeys) {
        screenState.slot(key).value
    }
    localState?.let { ls ->
        for (key in bindings.scopeKeys) {
            ls.slot(key).value
        }
    }

    luaVM?.let { vm ->
        vm.clearScope()
        localState?.let { ls ->
            for ((key, value) in ls.allValuesUntracked) {
                vm.setScopeState(key, value)
            }
            vm.onScopeChanged = { key, value ->
                ls.update(key, value)
            }
        }
    }

    val resolver = ExpressionResolver(luaVM, componentProps)

    val resolved = remember(definition, screenState.allValues) {
        definition.copy(style = resolver.style(definition.style))
    }

    val isVis = resolver.visible(resolved.visible)

    if (resolved.component.lowercase() == "spacer") {
        if (!isVis) return
        MelodySpacer()
    } else if (resolved.transition != null) {
        val transitionStr = resolver.string(resolved.transition)
        if (transitionStr.isNotEmpty()) {
            val (enter, exit) = resolveTransition(transitionStr)
            AnimatedVisibility(visible = isVis, enter = enter, exit = exit) {
                VisibleContent(resolved, resolver, luaVM, componentProps, localState, customComponents)
            }
        } else {
            if (!isVis) return
            VisibleContent(resolved, resolver, luaVM, componentProps, localState, customComponents)
        }
    } else {
        if (!isVis) return
        VisibleContent(resolved, resolver, luaVM, componentProps, localState, customComponents)
    }
}

@Composable
private fun VisibleContent(
    resolved: ComponentDefinition,
    resolver: ExpressionResolver,
    luaVM: LuaVM?,
    componentProps: Map<String, LuaValue>?,
    localState: com.melody.runtime.state.LocalState?,
    customComponents: Map<String, CustomComponentDefinition>
) {
    val componentType = resolved.component.lowercase()
    val handlesOwnTap = componentType == "button" || componentType == "stack"
    val hasContextMenu = !resolved.contextMenu.isNullOrEmpty()
    var showContextMenu by remember { mutableStateOf(false) }

    @OptIn(ExperimentalFoundationApi::class)
    val tapModifier = if (resolved.onTap != null && !handlesOwnTap) {
        if (hasContextMenu) {
            Modifier.combinedClickable(
                onClick = { executeLua(resolved.onTap, luaVM, componentProps, localState) },
                onLongClick = { showContextMenu = true }
            )
        } else {
            Modifier.clickable {
                executeLua(resolved.onTap, luaVM, componentProps, localState)
            }
        }
    } else if (hasContextMenu) {
        @OptIn(ExperimentalFoundationApi::class)
        Modifier.combinedClickable(
            onClick = {},
            onLongClick = { showContextMenu = true }
        )
    } else {
        Modifier
    }

    val parentDisabled = LocalIsDisabled.current
    val isDisabled = parentDisabled || resolver.disabled(resolved.disabled)

    CompositionLocalProvider(LocalIsDisabled provides isDisabled) {
        Box(modifier = tapModifier) {
            ComponentBody(resolved, resolver, luaVM, componentProps, localState, customComponents)
            if (hasContextMenu) {
                ContextMenuDropdown(
                    items = resolved.contextMenu!!,
                    expanded = showContextMenu,
                    onDismiss = { showContextMenu = false },
                    luaVM = luaVM,
                    componentProps = componentProps,
                    localState = localState
                )
            }
        }
    }
}

@Composable
private fun ComponentBody(
    definition: ComponentDefinition,
    resolver: ExpressionResolver,
    luaVM: LuaVM?,
    componentProps: Map<String, LuaValue>?,
    localState: com.melody.runtime.state.LocalState?,
    customComponents: Map<String, CustomComponentDefinition>
) {
    when (definition.component.lowercase()) {
        "text" -> MelodyText(
            definition = definition,
            resolvedText = resolver.string(definition.text)
        )

        "button" -> MelodyButton(
            definition = definition,
            resolvedLabel = resolver.string(definition.label),
            resolvedSystemImage = resolver.string(definition.systemImage).ifEmpty { null },
            onTap = { executeLua(definition.onTap, luaVM, componentProps, localState) }
        )

        "stack" -> {
            val stackContent: @Composable () -> Unit = {
                MelodyStack(
                    definition = definition,
                    renderChild = { child -> BoundComponentView(definition = child) },
                    resolveVisible = { resolver.visible(it) },
                    dynamicContent = { RenderDynamicItems(definition, luaVM, componentProps) }
                )
            }
            val stackHasContextMenu = !definition.contextMenu.isNullOrEmpty()
            var stackShowContextMenu by remember { mutableStateOf(false) }
            if (definition.onTap != null) {
                @OptIn(ExperimentalFoundationApi::class)
                val stackMod = if (stackHasContextMenu) {
                    Modifier.combinedClickable(
                        onClick = { executeLua(definition.onTap, luaVM, componentProps, localState) },
                        onLongClick = { stackShowContextMenu = true }
                    )
                } else {
                    Modifier.clickable {
                        executeLua(definition.onTap, luaVM, componentProps, localState)
                    }
                }
                Box(modifier = stackMod) {
                    stackContent()
                    if (stackHasContextMenu) {
                        ContextMenuDropdown(
                            items = definition.contextMenu!!,
                            expanded = stackShowContextMenu,
                            onDismiss = { stackShowContextMenu = false },
                            luaVM = luaVM,
                            componentProps = componentProps,
                            localState = localState
                        )
                    }
                }
            } else if (stackHasContextMenu) {
                @OptIn(ExperimentalFoundationApi::class)
                Box(modifier = Modifier.combinedClickable(
                    onClick = {},
                    onLongClick = { stackShowContextMenu = true }
                )) {
                    stackContent()
                    ContextMenuDropdown(
                        items = definition.contextMenu!!,
                        expanded = stackShowContextMenu,
                        onDismiss = { stackShowContextMenu = false },
                        luaVM = luaVM,
                        componentProps = componentProps,
                        localState = localState
                    )
                }
            } else {
                stackContent()
            }
        }

        "image" -> MelodyImage(
            definition = definition,
            resolvedSrc = resolver.string(definition.src).ifEmpty { null },
            resolvedSystemImage = resolver.string(definition.systemImage).ifEmpty { null }
        )

        "input" -> MelodyInput(
            definition = definition,
            resolvedLabel = resolver.string(definition.label),
            resolvedValue = resolver.string(definition.value),
            onChanged = { newValue ->
                definition.onChanged?.let { handler ->
                    luaVM?.setStateRaw("_input_value", LuaValue.StringVal(newValue))
                    executeLua("local value = state._input_value\n$handler", luaVM, componentProps, localState)
                }
            },
            onSubmit = definition.onSubmit?.let { handler ->
                { executeLua(handler, luaVM, componentProps, localState) }
            }
        )

        "list" -> RenderList(definition, resolver, luaVM, componentProps)
        "grid" -> RenderGrid(definition, resolver, luaVM, componentProps)

        "state_provider" -> StateProviderView(definition = definition)
        "loading" -> CircularProgressIndicator()
        "toggle" -> MelodyToggle(
            definition = definition,
            onChanged = definition.onChanged?.let { {
                executeLua(definition.onChanged, luaVM, componentProps, localState)
            } }
        )
        "divider" -> MelodyDivider(definition = definition)

        "picker" -> MelodyPicker(
            definition = definition,
            resolvedOptions = resolveOptions(definition.options, luaVM, componentProps),
            onChanged = definition.onChanged?.let { {
                executeLua(definition.onChanged, luaVM, componentProps, localState)
            } }
        )

        "slider" -> MelodySlider(
            definition = definition,
            onChanged = definition.onChanged?.let { {
                executeLua(definition.onChanged, luaVM, componentProps, localState)
            } }
        )

        "progress" -> MelodyProgress(
            definition = definition,
            resolvedValue = resolver.string(definition.value).ifEmpty { null },
            resolvedLabel = resolver.string(definition.label).ifEmpty { null }
        )

        "stepper" -> MelodyStepper(
            definition = definition,
            resolvedLabel = resolver.string(definition.label),
            onChanged = definition.onChanged?.let { {
                executeLua(definition.onChanged, luaVM, componentProps, localState)
            } }
        )

        "datepicker" -> MelodyDatePicker(
            definition = definition,
            onChanged = definition.onChanged?.let { {
                executeLua(definition.onChanged, luaVM, componentProps, localState)
            } }
        )

        "menu" -> MelodyMenu(
            definition = definition,
            resolvedLabel = resolver.string(definition.label),
            resolvedSystemImage = resolver.string(definition.systemImage).ifEmpty { null }
        ) {
            definition.children?.let { ComponentRenderer(components = it) }
        }

        "link" -> MelodyLink(
            definition = definition,
            resolvedLabel = resolver.string(definition.label),
            resolvedURL = resolver.string(definition.url),
            resolvedSystemImage = resolver.string(definition.systemImage).ifEmpty { null }
        )

        "disclosure" -> MelodyDisclosure(
            definition = definition,
            resolvedLabel = resolver.string(definition.label)
        ) {
            definition.children?.let { ComponentRenderer(components = it) }
        }

        "scroll" -> {
            val dir = resolver.direction(definition.direction)
            val isHorizontal = dir == DirectionAxis.Horizontal
            val spacing = definition.style?.spacing.resolved?.dp ?: 8.dp
            if (isHorizontal) {
                Row(
                    modifier = Modifier
                        .horizontalScroll(rememberScrollState())
                        .melodyStyle(definition.style),
                    horizontalArrangement = Arrangement.spacedBy(spacing)
                ) {
                    definition.children?.let { ComponentRenderer(components = it) }
                    RenderDynamicItems(definition, luaVM, componentProps)
                }
            } else {
                Column(
                    modifier = Modifier
                        .verticalScroll(rememberScrollState())
                        .melodyStyle(definition.style),
                    verticalArrangement = Arrangement.spacedBy(spacing)
                ) {
                    definition.children?.let { ComponentRenderer(components = it) }
                    RenderDynamicItems(definition, luaVM, componentProps)
                }
            }
        }

        "form" -> MelodyForm(definition = definition) {
            definition.children?.let { ComponentRenderer(components = it) }
            RenderDynamicItems(definition, luaVM, componentProps)
        }

        "section" -> MelodySection(
            definition = definition,
            resolvedLabel = resolver.string(definition.label),
            resolvedFooter = resolver.string(definition.footer),
            headerContent = definition.header,
            footerComponents = definition.footerContent
        ) {
            definition.children?.let { ComponentRenderer(components = it) }
            RenderDynamicItems(definition, luaVM, componentProps)
        }

        "chart" -> MelodyChart(
            definition = definition,
            resolvedItems = resolveListItems(definition.items, luaVM, componentProps)
        )

        else -> {
            val template = customComponents[definition.component]
            if (template != null) {
                CustomComponentView(template = template, instanceProps = definition.props)
            } else {
                Text("Unknown: ${definition.component}", color = Color.Red)
            }
        }
    }
}

// MARK: - Pre-resolved List Item

private data class RenderedListItem(
    val id: String,
    val components: List<ComponentDefinition>
)

private fun preResolveItems(
    definition: ComponentDefinition,
    luaVM: LuaVM?,
    componentProps: Map<String, LuaValue>?
): List<RenderedListItem> {
    val items = resolveListItems(definition.items, luaVM, componentProps)
    val script = definition.render ?: return emptyList()
    return items.mapIndexed { index, item ->
        // Pass a 1-based index since lua handles indices this way
        val comps = resolveRenderFunction(item, index + 1, script, luaVM)
        val stableId = comps.firstOrNull()?.id ?: "$index"
        RenderedListItem(id = stableId, components = comps)
    }
}

@Composable
private fun RenderedItemContent(item: RenderedListItem) {
    ComponentRenderer(components = item.components)
}

@Composable
private fun AnimatedRenderedItem(item: RenderedListItem, animName: String?) {
    if (animName != null) {
        val enter = when (animName.lowercase()) {
            "slide" -> fadeIn() + slideInVertically()
            "scale" -> fadeIn() + scaleIn()
            else -> fadeIn()
        }
        val exit = when (animName.lowercase()) {
            "slide" -> fadeOut() + slideOutVertically()
            "scale" -> fadeOut() + scaleOut()
            else -> fadeOut()
        }
        androidx.compose.animation.AnimatedVisibility(
            visible = true,
            enter = enter,
            exit = exit
        ) {
            RenderedItemContent(item)
        }
    } else {
        RenderedItemContent(item)
    }
}

@Composable
private fun RenderDynamicItems(
    definition: ComponentDefinition,
    luaVM: com.melody.runtime.engine.LuaVM?,
    componentProps: Map<String, LuaValue>?
) {
    if (definition.render == null) return
    val rendered = preResolveItems(definition, luaVM, componentProps)
    for (item in rendered) {
        key(item.id) {
            RenderedItemContent(item)
        }
    }
}

@Composable
private fun RenderList(
    definition: ComponentDefinition,
    resolver: ExpressionResolver,
    luaVM: com.melody.runtime.engine.LuaVM?,
    componentProps: Map<String, LuaValue>?
) {
    val rendered = preResolveItems(definition, luaVM, componentProps)
    val spacing = definition.style?.spacing.resolved?.dp ?: 8.dp
    val animName = definition.style?.animation

    val dir = resolver.direction(definition.direction)
    if (dir == DirectionAxis.Horizontal) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(spacing),
            modifier = Modifier
                .melodyStyle(definition.style)
                .horizontalScroll(rememberScrollState())
        ) {
            for (item in rendered) {
                key(item.id) {
                    AnimatedRenderedItem(item, animName)
                }
            }
        }
    } else if (LocalIsInFormContext.current) {
        for (item in rendered) {
            key(item.id) {
                AnimatedRenderedItem(item, animName)
            }
        }
    } else {
        Column(
            verticalArrangement = Arrangement.spacedBy(spacing),
            modifier = Modifier.melodyStyle(definition.style)
        ) {
            for (item in rendered) {
                key(item.id) {
                    AnimatedRenderedItem(item, animName)
                }
            }
        }
    }
}

@Composable
private fun RenderGrid(
    definition: ComponentDefinition,
    resolver: ExpressionResolver,
    luaVM: com.melody.runtime.engine.LuaVM?,
    componentProps: Map<String, LuaValue>?
) {
    val rendered = preResolveItems(definition, luaVM, componentProps)
    val columns = resolver.number(definition.columns)?.toInt() ?: 2
    val spacing = definition.style?.spacing.resolved?.dp ?: 8.dp
    val animName = definition.style?.animation

    val rows = rendered.chunked(columns)

    if (definition.lazy == true) {
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(spacing),
            modifier = Modifier.melodyStyle(definition.style)
        ) {
            items(rows.size) { rowIndex ->
                val rowItems = rows[rowIndex]
                Row(
                    horizontalArrangement = Arrangement.spacedBy(spacing),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    for (item in rowItems) {
                        key(item.id) {
                            Box(modifier = Modifier.weight(1f)) {
                                RenderedItemContent(item)
                            }
                        }
                    }
                    repeat(columns - rowItems.size) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    } else {
        Column(
            verticalArrangement = Arrangement.spacedBy(spacing),
            modifier = Modifier.melodyStyle(definition.style)
        ) {
            for (rowItems in rows) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(spacing),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    for (item in rowItems) {
                        key(item.id) {
                            Box(modifier = Modifier.weight(1f)) {
                                AnimatedRenderedItem(item, animName)
                            }
                        }
                    }
                    repeat(columns - rowItems.size) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun ContextMenuDropdown(
    items: List<ContextMenuItem>,
    expanded: Boolean,
    onDismiss: () -> Unit,
    luaVM: com.melody.runtime.engine.LuaVM?,
    componentProps: Map<String, LuaValue>?,
    localState: com.melody.runtime.state.LocalState?
) {
    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss) {
        val groups = groupBySections(items)
        for ((index, group) in groups.withIndex()) {
            if (index > 0) {
                HorizontalDivider()
            }
            for (item in group) {
                DropdownMenuItem(
                    text = {
                        Text(
                            item.label,
                            color = if (item.style == "destructive") MaterialTheme.colorScheme.error else Color.Unspecified
                        )
                    },
                    leadingIcon = item.systemImage?.let { iconName ->
                        { SystemImageMapper.Icon(iconName) }
                    },
                    onClick = {
                        onDismiss()
                        executeLua(item.onTap, luaVM, componentProps, localState)
                    }
                )
            }
        }
    }
}

/** Splits context menu items at `section = true` markers into groups of regular items. */
private fun groupBySections(items: List<ContextMenuItem>): List<List<ContextMenuItem>> {
    val groups = mutableListOf(mutableListOf<ContextMenuItem>())
    for (item in items) {
        if (item.section == true) {
            if (groups.last().isNotEmpty()) {
                groups.add(mutableListOf())
            }
        } else {
            groups.last().add(item)
        }
    }
    return groups.filter { it.isNotEmpty() }
}

internal fun executeLua(
    script: String?,
    luaVM: com.melody.runtime.engine.LuaVM?,
    componentProps: Map<String, LuaValue>?,
    localState: com.melody.runtime.state.LocalState?
) {
    if (script == null || luaVM == null) return
    luaVM.clearScope()
    localState?.let { ls ->
        for ((key, value) in ls.allValuesUntracked) {
            luaVM.setScopeState(key, value)
        }
    }
    val prefix = propsPrefix(luaVM, componentProps)
    luaVM.executeAsync(prefix + script) { result ->
        result.onFailure { e ->
            Log.e("Melody", "Lua error: ${e.message}")
        }
    }
}

internal fun resolveListItems(expression: String?, luaVM: com.melody.runtime.engine.LuaVM?, componentProps: Map<String, LuaValue>?): List<LuaValue> {
    if (expression == null || luaVM == null) return emptyList()
    return try {
        val prefix = propsPrefix(luaVM, componentProps)
        val trimmed = expression.trim()
        val result = if (trimmed.contains("\n") && listOf("local ", "if ", "for ", "while ", "repeat ", "return ", "do\n", "do ").any { trimmed.startsWith(it) }) {
            luaVM.execute(prefix + expression)
        } else {
            luaVM.execute("${prefix}return $expression")
        }
        (result as? LuaValue.ArrayVal)?.value ?: emptyList()
    } catch (_: Exception) { emptyList() }
}

internal fun resolveOptions(options: OptionsSource?, luaVM: com.melody.runtime.engine.LuaVM?, componentProps: Map<String, LuaValue>?): List<OptionDefinition> {
    if (options == null) return emptyList()
    return when (options) {
        is OptionsSource.Static -> options.options
        is OptionsSource.Expression -> {
            if (luaVM == null) return emptyList()
            try {
                val prefix = propsPrefix(luaVM, componentProps)
                val result = luaVM.execute("${prefix}return ${options.expr}")
                (result as? LuaValue.ArrayVal)?.value?.mapNotNull { item ->
                    val t = item.tableValue ?: return@mapNotNull null
                    val label = t["label"]?.stringValue ?: return@mapNotNull null
                    val value = t["value"]?.stringValue ?: return@mapNotNull null
                    OptionDefinition(label = label, value = value)
                } ?: emptyList()
            } catch (_: Exception) { emptyList() }
        }
    }
}

private fun resolveRenderFunction(item: LuaValue, index: Int, script: String, luaVM: com.melody.runtime.engine.LuaVM?): List<ComponentDefinition> {
    if (luaVM == null) return emptyList()
    luaVM.setStateRaw("_current_item", item)
    luaVM.setStateRaw("_current_index", LuaValue.NumberVal(index.toDouble()))
    return try {
        val result = luaVM.execute("""
            local item = state._current_item
            local index = state._current_index
            $script
        """.trimIndent())
        val table = result.tableValue ?: return emptyList()
        listOf(componentFromTable(table))
    } catch (e: Exception) {
        Log.e("Melody", "Render function error: ${e.message}")
        emptyList()
    }
}

private fun componentFromTable(table: Map<String, LuaValue>): ComponentDefinition {
    val def = ComponentDefinition(
        component = table["component"]?.stringValue ?: "text",
        id = table["id"]?.stringValue,
        text = table["text"]?.stringValue?.let { Value.fromString(it) },
        label = table["label"]?.stringValue?.let { Value.fromString(it) },
        onTap = table["onTap"]?.stringValue,
        src = table["src"]?.stringValue?.let { Value.fromString(it) },
        systemImage = table["systemImage"]?.stringValue?.let { Value.fromString(it) },
        direction = table["direction"]?.stringValue?.let { Value.Literal(DirectionAxis.from(it)) },
        visible = table["visible"]?.let { v ->
            when (v) {
                is LuaValue.BoolVal -> Value.Literal(v.value)
                is LuaValue.StringVal -> {
                    val expr = Value.extractExpression(v.value)
                    if (expr != null) Value.Expression(expr) else Value.Literal(v.value == "true")
                }
                else -> null
            }
        },
        placeholder = table["placeholder"]?.stringValue?.let { Value.fromString(it) },
        value = table["value"]?.stringValue?.let { Value.fromString(it) },
        onChanged = table["onChanged"]?.stringValue,
        items = table["items"]?.stringValue,
        render = table["render"]?.stringValue,
        inputType = table["inputType"]?.stringValue,
        stateKey = table["stateKey"]?.stringValue,
        min = table["min"]?.numberValue,
        max = table["max"]?.numberValue,
        step = table["step"]?.numberValue,
        url = table["url"]?.stringValue?.let { Value.fromString(it) },
        pickerStyle = table["pickerStyle"]?.stringValue,
        columns = table["columns"]?.let { v ->
            v.numberValue?.let { Value.Literal(it) }
                ?: v.stringValue?.let { Value.fromDouble(it) }
        },
        minColumnWidth = table["minColumnWidth"]?.let { v ->
            v.numberValue?.let { Value.Literal(it) }
                ?: v.stringValue?.let { Value.fromDouble(it) }
        },
        maxColumnWidth = table["maxColumnWidth"]?.let { v ->
            v.numberValue?.let { Value.Literal(it) }
                ?: v.stringValue?.let { Value.fromDouble(it) }
        },
        footer = table["footer"]?.stringValue?.let { Value.fromString(it) },
        formStyle = table["formStyle"]?.stringValue,
        shouldGrowToFitParent = table["shouldGrowToFitParent"]?.boolValue,
        transition = table["transition"]?.stringValue?.let { Value.fromString(it) },
        contextMenu = (table["contextMenu"] as? LuaValue.ArrayVal)?.value?.mapNotNull { item ->
            val t = item.tableValue ?: return@mapNotNull null
            val isSection = t["section"]?.boolValue ?: false
            val menuLabel = t["label"]?.stringValue ?: if (isSection) "" else return@mapNotNull null
            ContextMenuItem(
                label = menuLabel,
                systemImage = t["systemImage"]?.stringValue,
                style = t["style"]?.stringValue,
                onTap = t["onTap"]?.stringValue,
                section = if (isSection) true else null
            )
        },
        style = table["style"]?.tableValue?.let { styleFromTable(it) },
        children = (table["children"] as? LuaValue.ArrayVal)?.value?.mapNotNull {
            it.tableValue?.let { ct -> componentFromTable(ct) }
        },
        props = table["props"]?.tableValue?.mapValues { (_, v) ->
            val str = when (v) {
                is LuaValue.StringVal -> v.value
                is LuaValue.NumberVal -> if (v.value == v.value.toLong().toDouble()) v.value.toLong().toString() else v.value.toString()
                is LuaValue.BoolVal -> if (v.value) "true" else "false"
                else -> ""
            }
            Value.fromString(str)
        },
        bindings = (table["bindings"] as? LuaValue.ArrayVal)?.value?.mapNotNull { it.stringValue }
    )

    // Support lineLimit at the component root level (merged into style)
    val rootLineLimit = table["lineLimit"]?.numberValue?.toInt()
    if (rootLineLimit != null) {
        val style = def.style ?: ComponentStyle()
        if (style.lineLimit == null) {
            style.lineLimit = Value.Literal(rootLineLimit)
            def.style = style
        }
    }

    return def
}

private fun styleFromTable(table: Map<String, LuaValue>): ComponentStyle {
    return ComponentStyle(
        fontWeight = table["fontWeight"]?.stringValue,
        fontDesign = table["fontDesign"]?.stringValue,
        color = table["color"]?.stringValue?.let { Value.fromString(it) },
        backgroundColor = table["backgroundColor"]?.stringValue?.let { Value.fromString(it) },
        borderColor = table["borderColor"]?.stringValue?.let { Value.fromString(it) },
        alignment = table["alignment"]?.stringValue?.let { Value.Literal(ViewAlignment.from(it)) },
        animation = table["animation"]?.stringValue,
        contentMode = table["contentMode"]?.stringValue,
        overflow = table["overflow"]?.stringValue,
        lineLimit = table["lineLimit"]?.numberValue?.toInt()?.let { Value.Literal(it) },
        fontSize = table["fontSize"]?.numberValue?.let { Value.Literal(it) },
        padding = table["padding"]?.numberValue?.let { Value.Literal(it) },
        paddingTop = table["paddingTop"]?.numberValue?.let { Value.Literal(it) },
        paddingBottom = table["paddingBottom"]?.numberValue?.let { Value.Literal(it) },
        paddingLeft = table["paddingLeft"]?.numberValue?.let { Value.Literal(it) },
        paddingRight = table["paddingRight"]?.numberValue?.let { Value.Literal(it) },
        paddingHorizontal = table["paddingHorizontal"]?.numberValue?.let { Value.Literal(it) },
        paddingVertical = table["paddingVertical"]?.numberValue?.let { Value.Literal(it) },
        borderRadius = table["borderRadius"]?.numberValue?.let { Value.Literal(it) },
        cornerRadius = table["cornerRadius"]?.numberValue?.let { Value.Literal(it) },
        borderWidth = table["borderWidth"]?.numberValue?.let { Value.Literal(it) },
        width = parseLuaSize(table["width"]),
        height = parseLuaSize(table["height"]),
        minWidth = parseLuaSize(table["minWidth"]),
        minHeight = parseLuaSize(table["minHeight"]),
        maxWidth = parseLuaSize(table["maxWidth"]),
        maxHeight = parseLuaSize(table["maxHeight"]),
        spacing = table["spacing"]?.numberValue?.let { Value.Literal(it) },
        opacity = table["opacity"]?.numberValue?.let { Value.Literal(it) },
        margin = table["margin"]?.numberValue?.let { Value.Literal(it) },
        marginTop = table["marginTop"]?.numberValue?.let { Value.Literal(it) },
        marginBottom = table["marginBottom"]?.numberValue?.let { Value.Literal(it) },
        marginLeft = table["marginLeft"]?.numberValue?.let { Value.Literal(it) },
        marginRight = table["marginRight"]?.numberValue?.let { Value.Literal(it) },
        scale = table["scale"]?.numberValue?.let { Value.Literal(it) },
        rotation = table["rotation"]?.numberValue?.let { Value.Literal(it) },
        aspectRatio = table["aspectRatio"]?.numberValue?.let { Value.Literal(it) },
        layoutPriority = table["layoutPriority"]?.numberValue?.let { Value.Literal(it) },
        shadow = table["shadow"]?.tableValue?.let { s ->
            ShadowStyle(
                x = s["x"]?.numberValue,
                y = s["y"]?.numberValue,
                blur = s["blur"]?.numberValue,
                color = s["color"]?.stringValue
            )
        }
    )
}

/** Parse a size value from Lua: number or "full" → -1.0 */
private fun parseLuaSize(value: LuaValue?): Value<Double>? {
    if (value == null || value is LuaValue.Nil) return null
    value.numberValue?.let { return Value.Literal(it) }
    if (value.stringValue?.lowercase() == "full") return Value.Literal(-1.0)
    value.stringValue?.let { return Value.fromDouble(it) }
    return null
}

private fun resolveTransition(value: String?): Pair<EnterTransition, ExitTransition> {
    if (value == null) return fadeIn() + expandVertically() to fadeOut() + shrinkVertically()
    val parts = value.lowercase().split(".")
    var enter: EnterTransition? = null
    var exit: ExitTransition? = null
    var i = 0
    while (i < parts.size) {
        when (parts[i]) {
            "opacity" -> {
                enter = enter?.plus(fadeIn()) ?: fadeIn()
                exit = exit?.plus(fadeOut()) ?: fadeOut()
            }
            "slide" -> {
                enter = enter?.plus(slideInHorizontally()) ?: slideInHorizontally()
                exit = exit?.plus(slideOutHorizontally()) ?: slideOutHorizontally()
            }
            "scale" -> {
                enter = enter?.plus(scaleIn()) ?: scaleIn()
                exit = exit?.plus(scaleOut()) ?: scaleOut()
            }
            "move" -> {
                i++
                val direction = if (i < parts.size) parts[i] else "bottom"
                when (direction) {
                    "top" -> {
                        enter = enter?.plus(slideInVertically { -it }) ?: slideInVertically { -it }
                        exit = exit?.plus(slideOutVertically { -it }) ?: slideOutVertically { -it }
                    }
                    else -> {
                        enter = enter?.plus(slideInVertically { it }) ?: slideInVertically { it }
                        exit = exit?.plus(slideOutVertically { it }) ?: slideOutVertically { it }
                    }
                }
            }
        }
        i++
    }
    return (enter ?: fadeIn()) to (exit ?: fadeOut())
}

internal fun propsPrefix(luaVM: com.melody.runtime.engine.LuaVM, componentProps: Map<String, LuaValue>?): String {
    return componentProps?.let { luaVM.propsPrefix(it) } ?: ""
}
