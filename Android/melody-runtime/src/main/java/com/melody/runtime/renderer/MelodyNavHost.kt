package com.melody.runtime.renderer

import android.util.Log
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.ScreenDefinition
import com.melody.core.schema.Value
import com.melody.runtime.components.SystemImageMapper
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.navigation.Navigator
import com.melody.runtime.state.MelodyEventBus
import com.melody.runtime.state.ScreenVMStore

/**
 * Navigation host that manages a stack of screens with a top app bar.
 * Simulates iOS NavigationStack behavior using a Compose-based stack.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MelodyNavHost(
    navigator: Navigator,
    rootScreen: ScreenDefinition
) {
    val rootPath by navigator.rootPath
    val screenVMStore = LocalScreenVMStore.current
    val eventBus = LocalEventBus.current

    // Track previous stack state to detect navigation changes and clean up
    var previousRootPath by remember { mutableStateOf(rootPath) }
    var previousStack by remember { mutableStateOf(listOf<String>()) }

    LaunchedEffect(rootPath, navigator.path.toList()) {
        val currentStack = navigator.path.toList()

        if (rootPath != previousRootPath) {
            // Replace detected: clean up old root + entire old stack
            val toRemove = mutableListOf(previousRootPath)
            toRemove.addAll(previousStack)
            screenVMStore.removeAll(toRemove, eventBus)
        } else if (currentStack.size < previousStack.size &&
            (currentStack.isEmpty() || previousStack.take(currentStack.size) == currentStack)) {
            // goBack detected: clean up popped entries
            val popped = previousStack.drop(currentStack.size)
            screenVMStore.removeAll(popped, eventBus)
        }

        previousRootPath = rootPath
        previousStack = currentStack
    }

    key(rootPath) {
        val actualRootScreen = navigator.screen(rootPath) ?: rootScreen
        val hasStack = navigator.path.isNotEmpty()
        val currentScreen = if (hasStack) {
            navigator.screen(navigator.path.last()) ?: actualRootScreen
        } else {
            actualRootScreen
        }
        val currentPath = if (hasStack) navigator.path.last() else rootPath
        val staticTitle = currentScreen.title ?: currentScreen.id
        var titleOverride by remember(currentScreen.id) { mutableStateOf<String?>(null) }
        val title = titleOverride ?: staticTitle

        var toolbarVM by remember { mutableStateOf<LuaVM?>(null) }

        val topBarTitle: @Composable () -> Unit = {
            TitleWithMenu(title, currentScreen.titleMenu, currentScreen.titleMenuBuilder, toolbarVM)
        }
        val topBarNavIcon: @Composable () -> Unit = {
            if (hasStack) {
                IconButton(onClick = { navigator.goBack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back"
                    )
                }
            }
        }
        val topBarActions: @Composable (androidx.compose.foundation.layout.RowScope.() -> Unit) = {
            ToolbarActions(currentScreen.toolbar, toolbarVM)
        }

        Scaffold(
            topBar = {
                if (currentScreen.titleDisplayMode == "large") {
                    LargeTopAppBar(
                        title = topBarTitle,
                        navigationIcon = topBarNavIcon,
                        actions = topBarActions
                    )
                } else {
                    TopAppBar(
                        title = topBarTitle,
                        navigationIcon = topBarNavIcon,
                        actions = topBarActions
                    )
                }
            }
        ) { innerPadding ->
            Box(modifier = Modifier.padding(innerPadding)) {
                ScreenView(
                    definition = currentScreen,
                    actualPath = currentPath,
                    onVMReady = { toolbarVM = it },
                    onTitleChange = { titleOverride = it }
                )
            }
        }
    }
}

@Composable
fun ToolbarActions(
    items: List<ComponentDefinition>?,
    luaVM: LuaVM?
) {
    if (items.isNullOrEmpty() || luaVM == null) return
    for (item in items) {
        if (!isToolbarItemVisible(item, luaVM)) continue
        when (item.component.lowercase()) {
            "menu" -> ToolbarMenu(item, luaVM)
            else -> ToolbarButton(item, luaVM)
        }
    }
}

private fun resolveToolbarString(value: Value<String>?, vm: LuaVM): String? {
    if (value == null) return null
    return when (value) {
        is Value.Literal -> value.value
        is Value.Expression -> try {
            when (val result = vm.execute("return ${value.expr}")) {
                is LuaValue.StringVal -> result.value
                is LuaValue.Nil -> null
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }
}

private fun isToolbarItemVisible(item: ComponentDefinition, vm: LuaVM): Boolean {
    val visible = item.visible ?: return true
    return when (visible) {
        is Value.Literal -> visible.value
        is Value.Expression -> try {
            when (val result = vm.evaluate(visible.expr)) {
                is LuaValue.BoolVal -> result.value
                is LuaValue.Nil -> false
                else -> true
            }
        } catch (_: Exception) {
            true
        }
    }
}

@Composable
private fun ToolbarButton(item: ComponentDefinition, luaVM: LuaVM) {
    val icon = resolveToolbarString(item.systemImage, luaVM)
    IconButton(onClick = {
        item.onTap?.let { script ->
            luaVM.executeAsync(script) { result ->
                result.onFailure { e ->
                    Log.e("Melody", "Toolbar action error: ${e.message}")
                }
            }
        }
    }) {
        if (icon != null) {
            SystemImageMapper.Icon(icon)
        } else {
            Text(resolveToolbarString(item.label, luaVM)
                ?: resolveToolbarString(item.text, luaVM)
                ?: "")
        }
    }
}

@Composable
fun TitleWithMenu(
    title: String,
    titleMenu: List<ComponentDefinition>?,
    titleMenuBuilder: String?,
    luaVM: LuaVM?
) {
    val hasBuilder = !titleMenuBuilder.isNullOrEmpty() && luaVM != null
    val hasStaticItems = !titleMenu.isNullOrEmpty() && luaVM != null

    if (!hasBuilder && !hasStaticItems) {
        Text(title)
        return
    }

    var expanded by remember { mutableStateOf(false) }

    Box {
        Row(
            modifier = Modifier.clickable { expanded = true },
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
        ) {
            Text(title)
            Icon(
                imageVector = Icons.Filled.ArrowDropDown,
                contentDescription = "Title menu",
                modifier = Modifier.size(24.dp)
            )
        }

        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            if (hasBuilder) {
                val dynamicItems = evaluateTitleMenuBuilder(titleMenuBuilder!!, luaVM!!)
                for (item in dynamicItems) {
                    val label = (item["label"] as? LuaValue.StringVal)?.value ?: ""
                    val systemImage = (item["systemImage"] as? LuaValue.StringVal)?.value
                    val onTap = (item["onTap"] as? LuaValue.StringVal)?.value

                    DropdownMenuItem(
                        text = { Text(label) },
                        leadingIcon = systemImage?.let { img ->
                            { SystemImageMapper.Icon(img) }
                        },
                        onClick = {
                            expanded = false
                            onTap?.let { script ->
                                luaVM.executeAsync(script) { result ->
                                    result.onFailure { e ->
                                        Log.e("Melody", "Title menu error: ${e.message}")
                                    }
                                }
                            }
                        }
                    )
                }
            } else {
                for (child in titleMenu!!) {
                    val resolvedIcon = resolveToolbarString(child.systemImage, luaVM!!)
                    val childLabel = resolveToolbarString(child.label, luaVM!!)
                        ?: resolveToolbarString(child.text, luaVM!!)
                        ?: ""
                    DropdownMenuItem(
                        text = { Text(childLabel) },
                        leadingIcon = resolvedIcon?.let { img ->
                            { SystemImageMapper.Icon(img) }
                        },
                        onClick = {
                            expanded = false
                            child.onTap?.let { script ->
                                luaVM!!.executeAsync(script) { result ->
                                    result.onFailure { e ->
                                        Log.e("Melody", "Title menu error: ${e.message}")
                                    }
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

private fun evaluateTitleMenuBuilder(script: String, vm: LuaVM): List<Map<String, LuaValue>> {
    return try {
        when (val result = vm.execute(script)) {
            is LuaValue.ArrayVal -> result.value.mapNotNull { item ->
                (item as? LuaValue.TableVal)?.value
            }
            else -> emptyList()
        }
    } catch (e: Exception) {
        Log.e("Melody", "Title menu builder error: ${e.message}")
        emptyList()
    }
}

@Composable
private fun ToolbarMenu(item: ComponentDefinition, luaVM: LuaVM) {
    var expanded by remember { mutableStateOf(false) }
    val icon = resolveToolbarString(item.systemImage, luaVM)

    Box {
        IconButton(onClick = { expanded = true }) {
            if (icon != null) {
                SystemImageMapper.Icon(icon)
            } else {
                Text(resolveToolbarString(item.label, luaVM)
                    ?: resolveToolbarString(item.text, luaVM)
                    ?: "")
            }
        }

        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            item.children?.forEach { child ->
                if (!isToolbarItemVisible(child, luaVM)) return@forEach
                val resolvedChildIcon = resolveToolbarString(child.systemImage, luaVM)
                val childLabel = resolveToolbarString(child.label, luaVM)
                    ?: resolveToolbarString(child.text, luaVM)
                    ?: ""
                DropdownMenuItem(
                    text = { Text(childLabel) },
                    leadingIcon = resolvedChildIcon?.let { img ->
                        { SystemImageMapper.Icon(img) }
                    },
                    onClick = {
                        expanded = false
                        child.onTap?.let { script ->
                            luaVM.executeAsync(script) { result ->
                                result.onFailure { e ->
                                    Log.e("Melody", "Toolbar menu error: ${e.message}")
                                }
                            }
                        }
                    }
                )
            }
        }
    }
}
