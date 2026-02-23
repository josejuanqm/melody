package com.melody.runtime.renderer

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import com.melody.core.schema.ScreenDefinition
import com.melody.core.schema.TabDefinition
import com.melody.runtime.components.SystemImageMapper
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.navigation.Navigator
import com.melody.runtime.navigation.TabCoordinator
import com.melody.runtime.presentation.*
import com.melody.runtime.state.ScreenVMStore

/** Filter tabs to those visible on the current platform. */
private fun filterTabsByPlatform(tabs: List<TabDefinition>): List<TabDefinition> {
    return tabs.filter { tab ->
        val platforms = tab.platforms
        platforms == null || platforms.isEmpty() || platforms.any { it.lowercase() == "android" }
    }
}

/** Evaluate which platform-filtered tabs should be visible based on their `visible` value. */
private fun evaluateTabVisibility(
    platformTabs: List<TabDefinition>,
    expressionVM: LuaVM?
): List<TabDefinition> {
    val resolver = ExpressionResolver(expressionVM, null)
    return platformTabs.filter { tab ->
        resolver.visible(tab.visible)
    }
}

/**
 * Renders a tab bar for screens that declare tabs.
 * Supports dynamic `visible` expressions on tabs — evaluated via a lightweight LuaVM.
 * Port of iOS TabContainerView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TabContainerView(definition: ScreenDefinition) {
    val parentNavigator = LocalNavigator.current
    val rootNavigator = LocalRootNavigator.current
    val store = LocalMelodyStore.current
    val eventBus = LocalEventBus.current
    val screenVMStore = LocalScreenVMStore.current
    val context = androidx.compose.ui.platform.LocalContext.current
    val themeColors = LocalThemeColors.current
    val appLuaPrelude = LocalAppLuaPrelude.current
    val pluginRegistry = LocalPluginRegistry.current
    val allTabs = definition.tabs ?: return
    val platformTabs = remember(allTabs) { filterTabsByPlatform(allTabs) }
    if (platformTabs.isEmpty()) return

    val hasDynamicTabs = remember(platformTabs) { platformTabs.any { it.visible != null } }

    var expressionVM by remember { mutableStateOf<LuaVM?>(null) }

    var visibleTabs by remember { mutableStateOf(platformTabs) }

    val tabNavigators = remember { mutableStateMapOf<String, Navigator>() }

    // Track previous per-tab stacks for cleanup
    val previousTabStacks = remember { mutableMapOf<String, List<String>>() }

    val tabCoordinator = remember {
        TabCoordinator(
            tabIds = platformTabs.map { it.id },
            initialTabId = platformTabs.first().id
        )
    }

    DisposableEffect(hasDynamicTabs) {
        var observerIdLocal: Int? = null
        var vmLocal: LuaVM? = null

        if (hasDynamicTabs) {
            val vm = LuaVM()
            vmLocal = vm
            vm.registerMelodyFunction("storeGet") { args ->
                args.firstOrNull()?.stringValue?.let { store.get(it) } ?: LuaValue.Nil
            }
            expressionVM = vm

            val allScreens = parentNavigator.registeredScreens
            val initialVisible = evaluateTabVisibility(platformTabs, vm)
            visibleTabs = initialVisible

            for (tab in initialVisible) {
                if (!tabNavigators.containsKey(tab.id)) {
                    val nav = Navigator()
                    nav.rootPath.value = tab.screen
                    nav.registerScreens(allScreens)
                    tabNavigators[tab.id] = nav
                }
            }
            tabCoordinator.updateTabIds(initialVisible.map { it.id })

            observerIdLocal = eventBus.observe("tabVisibilityChanged") { _ ->
                val newVisible = evaluateTabVisibility(platformTabs, vm)
                for (tab in newVisible) {
                    if (!tabNavigators.containsKey(tab.id)) {
                        val nav = Navigator()
                        nav.rootPath.value = tab.screen
                        nav.registerScreens(allScreens)
                        tabNavigators[tab.id] = nav
                    }
                }
                visibleTabs = newVisible
                tabCoordinator.updateTabIds(newVisible.map { it.id })
            }
        } else {
            visibleTabs = platformTabs
            val allScreens = parentNavigator.registeredScreens
            for (tab in platformTabs) {
                if (!tabNavigators.containsKey(tab.id)) {
                    val nav = Navigator()
                    nav.rootPath.value = tab.screen
                    nav.registerScreens(allScreens)
                    tabNavigators[tab.id] = nav
                }
            }
            tabCoordinator.updateTabIds(platformTabs.map { it.id })
        }

        onDispose {
            observerIdLocal?.let { eventBus.removeObserver(it) }
            vmLocal?.close()
            expressionVM = null
        }
    }

    val tabs = visibleTabs
    if (tabs.isEmpty()) return

    val selectedTabId by tabCoordinator.selectedTabId
    val selectedTab = tabs.find { it.id == selectedTabId } ?: tabs.first()
    val nav = tabNavigators[selectedTab.id]

    // Track per-tab stack changes and clean up removed entries
    for (tab in tabs) {
        val tabNav = tabNavigators[tab.id] ?: continue
        val currentStack = tabNav.path.toList()
        val prevStack = previousTabStacks[tab.id] ?: emptyList()

        if (currentStack.size < prevStack.size &&
            (currentStack.isEmpty() || prevStack.take(currentStack.size) == currentStack)) {
            val popped = prevStack.drop(currentStack.size)
            screenVMStore.removeAll(popped, eventBus)
        }

        previousTabStacks[tab.id] = currentStack
    }

    val hasStack = nav != null && nav.path.isNotEmpty()
    val currentScreen = if (nav != null) {
        if (hasStack) {
            nav.screen(nav.path.last())
        } else {
            nav.screen(selectedTab.screen)
        }
    } else null
    val staticTitle = currentScreen?.title ?: selectedTab.title
    var titleOverride by remember(currentScreen?.id) { mutableStateOf<String?>(null) }
    val title = titleOverride ?: staticTitle

    var toolbarVM by remember { mutableStateOf<LuaVM?>(null) }

    // Create a dedicated VM for the tab container's own toolbar items
    var tabToolbarVM by remember { mutableStateOf<LuaVM?>(null) }
    val tabPresentation = remember { PresentationCoordinator() }

    DisposableEffect(definition.toolbar != null) {
        if (definition.toolbar != null) {
            val vm = LuaVM()
            registerMelodyFunctions(
                vm, parentNavigator, rootNavigator, store, eventBus,
                tabCoordinator, tabPresentation, null, context, null
            )
            if (themeColors.isNotEmpty()) {
                val entries = themeColors.entries.joinToString(", ") { (k, v) -> "$k = \"$v\"" }
                try { vm.execute("theme = { $entries }") } catch (_: Exception) {}
            }
            val prelude = appLuaPrelude
            if (prelude != null) {
                try { vm.execute(prelude) } catch (_: Exception) {}
            }
            tabToolbarVM = vm
        }
        onDispose {
            tabToolbarVM?.close()
            tabToolbarVM = null
        }
    }

    val topBarTitle: @Composable () -> Unit = {
        TitleWithMenu(title, currentScreen?.titleMenu, currentScreen?.titleMenuBuilder, toolbarVM)
    }
    val topBarNavIcon: @Composable () -> Unit = {
        if (hasStack && nav != null) {
            IconButton(onClick = { nav.goBack() }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back"
                )
            }
        }
    }
    val topBarActions: @Composable (androidx.compose.foundation.layout.RowScope.() -> Unit) = {
        ToolbarActions(definition.toolbar, tabToolbarVM)
        ToolbarActions(currentScreen?.toolbar, toolbarVM)
    }

    // Handle alerts/sheets from tab container toolbar actions
    val tabAlertConfig = tabPresentation.alert.value
    if (tabAlertConfig != null) {
        AlertDialog(
            onDismissRequest = { tabPresentation.alert.value = null },
            title = { Text(tabAlertConfig.title) },
            text = tabAlertConfig.message?.let { msg -> { Text(msg) } },
            confirmButton = {
                Row {
                    for (button in tabAlertConfig.buttons) {
                        TextButton(onClick = {
                            tabPresentation.alert.value = null
                            button.onTap?.let { script ->
                                tabToolbarVM?.executeAsync(script) { _ -> }
                            }
                        }) {
                            Text(
                                button.title,
                                color = when (button.style) {
                                    "destructive" -> MaterialTheme.colorScheme.error
                                    else -> MaterialTheme.colorScheme.primary
                                }
                            )
                        }
                    }
                }
            }
        )
    }

    val tabSheetConfig = tabPresentation.sheet.value
    if (tabSheetConfig != null) {
        val sheetScreen = parentNavigator.screen(tabSheetConfig.screenPath)
        if (sheetScreen != null) {
            ModalBottomSheet(
                onDismissRequest = { tabPresentation.sheet.value = null },
            ) {
                CompositionLocalProvider(
                    LocalMelodyDismiss provides { tabPresentation.sheet.value = null }
                ) {
                    ScreenView(
                        definition = sheetScreen,
                        actualPath = tabSheetConfig.screenPath,
                        isSheet = true
                    )
                }
            }
        }
    }

    Scaffold(
        topBar = {
            if (currentScreen?.titleDisplayMode == "large") {
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
        },
        bottomBar = {
            NavigationBar {
                for (tab in tabs) {
                    NavigationBarItem(
                        icon = { SystemImageMapper.Icon(tab.icon) },
                        label = { Text(tab.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        selected = selectedTabId == tab.id,
                        onClick = { tabCoordinator.switchTab(tab.id) }
                    )
                }
            }
        }
    ) { innerPadding ->
        if (nav != null) {
            CompositionLocalProvider(
                LocalNavigator provides nav,
                LocalTabCoordinator provides tabCoordinator
            ) {
                val rootScreen = nav.screen(selectedTab.screen)
                if (rootScreen != null) {
                    Box(modifier = Modifier.padding(innerPadding)) {
                        val topPath = if (nav.path.isNotEmpty()) nav.path.last() else selectedTab.screen
                        val screenDef = if (nav.path.isNotEmpty()) nav.screen(nav.path.last()) ?: rootScreen else rootScreen
                        ScreenView(
                            definition = screenDef,
                            actualPath = topPath,
                            onVMReady = { toolbarVM = it },
                            onTitleChange = { titleOverride = it }
                        )
                    }
                }
            }
        }
    }
}
