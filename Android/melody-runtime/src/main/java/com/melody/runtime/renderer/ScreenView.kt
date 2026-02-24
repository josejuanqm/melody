package com.melody.runtime.renderer

import android.util.Log
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.melody.core.schema.SearchConfig
import com.melody.core.schema.ScreenDefinition
import com.melody.runtime.engine.LuaError
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.networking.MelodyHTTP
import com.melody.runtime.networking.MelodyWebSocket
import com.melody.runtime.navigation.Navigator
import com.melody.runtime.presentation.*
import com.melody.runtime.components.melodyStyle
import com.melody.runtime.state.ScreenState
import com.melody.runtime.state.ScreenVMEntry
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

/**
 * Renders a single screen from a ScreenDefinition.
 * Port of iOS ScreenView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScreenView(
    definition: ScreenDefinition,
    actualPath: String? = null,
    isSheet: Boolean = false,
    onVMReady: ((LuaVM?) -> Unit)? = null,
    onTitleChange: ((String) -> Unit)? = null
) {
    val navigator = LocalNavigator.current
    val rootNavigator = LocalRootNavigator.current
    val store = LocalMelodyStore.current
    val themeColors = LocalThemeColors.current
    val tabCoordinator = LocalTabCoordinator.current
    val melodyDismiss = LocalMelodyDismiss.current
    val appLuaPrelude = LocalAppLuaPrelude.current
    val eventBus = LocalEventBus.current
    val pluginRegistry = LocalPluginRegistry.current
    val context = LocalContext.current
    val screenVMStore = LocalScreenVMStore.current

    // Indirect ref so Lua callbacks (registered once) always call the latest callback
    val currentOnTitleChange by rememberUpdatedState(onTitleChange)

    val cacheKey = if (isSheet) null else (actualPath ?: definition.path)
    // Observe store generation so screens re-create VMs after hot reload clears the store
    val storeGen = screenVMStore.generation.intValue
    val cachedEntry = remember(cacheKey, storeGen) { cacheKey?.let { screenVMStore.getOrNull(it) } }

    val screenState = cachedEntry?.screenState ?: remember(cacheKey, storeGen) { ScreenState() }
    var luaVM by remember(cacheKey, storeGen) { mutableStateOf(cachedEntry?.luaVM) }
    var error by remember(cacheKey, storeGen) { mutableStateOf<String?>(null) }
    val presentation = cachedEntry?.presentation ?: remember(cacheKey, storeGen) { PresentationCoordinator() }
    var eventBusId by remember(cacheKey, storeGen) { mutableIntStateOf(cachedEntry?.eventBusId ?: -1) }
    val webSockets = cachedEntry?.webSockets ?: remember(cacheKey, storeGen) { mutableMapOf<Int, MelodyWebSocket>() }
    val nextWsId = cachedEntry?.nextWsId ?: remember(cacheKey, storeGen) { mutableIntStateOf(1) }

    BackHandler(enabled = navigator.path.isNotEmpty()) {
        navigator.goBack()
    }

    LaunchedEffect(cacheKey, storeGen) {
        if (cachedEntry != null) {
            // Reconnect to cached VM — re-wire UI callbacks, skip onMount
            val vm = cachedEntry.luaVM
            luaVM = vm

            vm.onStateChanged = { key, value ->
                screenState.update(key, value)
            }
            screenState.syncToLua = { key, value ->
                vm.setState(key, value)
            }

            onVMReady?.invoke(vm)
            return@LaunchedEffect
        }

        // Fresh VM setup
        try {
            val vm = LuaVM()
            luaVM = vm

            screenState.initialize(definition.state)

            for ((key, value) in screenState.allValues) {
                vm.setState(key, value)
            }

            if (themeColors.isNotEmpty()) {
                val entries = themeColors.entries.joinToString(", ") { (k, v) -> "$k = \"$v\"" }
                vm.execute("theme = { $entries }")
            }

            pluginRegistry?.register(vm)

            vm.execute("params = {}")
            actualPath?.let { actual ->
                val routeParams = navigator.extractParams(actual, definition.path)
                for ((key, value) in routeParams) {
                    vm.setGlobal("params", key, LuaValue.StringVal(value))
                }
                navigator.navigationProps.remove(actual)?.let { navProps ->
                    for ((key, value) in navProps) {
                        vm.setGlobal("params", key, value)
                    }
                }
            }

            vm.execute("context = { isSheet = ${isSheet} }")

            vm.onStateChanged = { key, value ->
                screenState.update(key, value)
            }

            screenState.syncToLua = { key, value ->
                vm.setState(key, value)
            }

            registerMelodyFunctions(
                vm, navigator, rootNavigator, store, eventBus,
                tabCoordinator, presentation, melodyDismiss, context,
                { title -> currentOnTitleChange?.invoke(title) }
            )

            eventBusId = eventBus.register(vm)

            vm.execute("""
                _melody_event_listeners = {}
                function melody.on(event, callback)
                    if not _melody_event_listeners[event] then
                        _melody_event_listeners[event] = {}
                    end
                    table.insert(_melody_event_listeners[event], callback)
                end
                function melody.off(event, callback)
                    if callback == nil then
                        _melody_event_listeners[event] = nil
                    elseif _melody_event_listeners[event] then
                        for i, cb in ipairs(_melody_event_listeners[event]) do
                            if cb == callback then
                                table.remove(_melody_event_listeners[event], i)
                                break
                            end
                        end
                    end
                end
            """.trimIndent())

            vm.registerMelodyFunction("emit") { args ->
                val event = args.firstOrNull()?.stringValue
                if (event != null) {
                    val data = if (args.size > 1) args[1] else LuaValue.Nil
                    eventBus.emit(event, data)
                }
                LuaValue.Nil
            }

            registerWebSocketFunctions(vm, webSockets, nextWsId)

            appLuaPrelude?.let { vm.execute(it) }

            // Store entry for reuse across navigation
            cacheKey?.let { key ->
                screenVMStore.put(key, ScreenVMEntry(
                    luaVM = vm,
                    screenState = screenState,
                    webSockets = webSockets,
                    nextWsId = nextWsId,
                    eventBusId = eventBusId,
                    presentation = presentation
                ))
            }

            onVMReady?.invoke(vm)

            definition.onMount?.let { onMount ->
                vm.executeAsync(onMount) { result ->
                    result.onFailure { e ->
                        Log.e("Melody", "onMount error: ${e.message}")
                    }
                }
            }

        } catch (e: Exception) {
            error = e.message
        }
    }

    DisposableEffect(cacheKey, storeGen) {
        onDispose {
            if (cacheKey != null) {
                // Cached screen: only detach UI callbacks, keep VM alive
                luaVM?.onStateChanged = null
                screenState.syncToLua = null
                onVMReady?.invoke(null)
            } else {
                // Sheet or uncached: full cleanup
                for (ws in webSockets.values) {
                    ws.disconnect()
                }
                webSockets.clear()
                if (eventBusId >= 0) {
                    eventBus.unregister(eventBusId)
                }
                luaVM?.close()
            }
        }
    }

    val alertConfig = presentation.alert.value
    if (alertConfig != null) {
        AlertDialog(
            onDismissRequest = { presentation.alert.value = null },
            title = { Text(alertConfig.title) },
            text = alertConfig.message?.let { msg -> { Text(msg) } },
            confirmButton = {
                Row {
                    for (button in alertConfig.buttons) {
                        TextButton(onClick = {
                            presentation.alert.value = null
                            button.onTap?.let { script ->
                                luaVM?.executeAsync(script) { result ->
                                    result.onFailure { e ->
                                        Log.e("Melody", "Alert button error: ${e.message}")
                                    }
                                }
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

    val sheetConfig = presentation.sheet.value
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = presentation.sheet.value?.detent != "medium",
    )
    if (sheetConfig != null) {
        val sheetScreen = navigator.screen(sheetConfig.screenPath)
        if (sheetScreen != null) {
            ModalBottomSheet(
                onDismissRequest = { presentation.sheet.value = null },
                sheetState = sheetState,
                modifier = Modifier.padding(top = 100.dp).then(
                    with(LocalDensity.current) {
                        Modifier.padding(bottom = WindowInsets.ime.getBottom(this).toDp())
                    }
                )
            ) {
                CompositionLocalProvider(
                    LocalMelodyDismiss provides { presentation.sheet.value = null }
                ) {
                    ScreenView(
                        definition = sheetScreen,
                        actualPath = sheetConfig.screenPath,
                        isSheet = true
                    )
                }
            }
        }
    }

    CompositionLocalProvider(
        LocalScreenState provides screenState,
        LocalLuaVM provides luaVM
    ) {
        when {
            error != null -> ErrorOverlay(error!!, definition.id)
            luaVM != null -> {
                val wrapper = definition.wrapper?.lowercase()
                    ?: if (definition.scrollEnabled != false || definition.search != null) "scroll" else "vstack"
                val sizeModifier = if (isSheet) Modifier.fillMaxWidth() else Modifier.fillMaxSize()

                val inset = definition.contentInset
                val insetModifier = if (inset != null) {
                    Modifier.padding(
                        start = inset.resolvedLeading.dp,
                        end = inset.resolvedTrailing.dp,
                        top = inset.resolvedTop.dp,
                        bottom = inset.resolvedBottom.dp
                    )
                } else Modifier

                val isLoading = screenState.get("loading") == LuaValue.BoolVal(true)
                val hasRefresh = definition.onRefresh != null
                val refreshState = rememberPullToRefreshState()
                val onRefresh: (() -> Unit)? = when {
                    definition.onRefresh != null -> {
                        { luaVM?.executeAsync(definition.onRefresh ?: "") { } }
                    }
                    else -> null
                }

                PullToRefreshBox(
                    isRefreshing = isLoading,
                    onRefresh = onRefresh ?: {},
                    state = refreshState
                ) {
                    Column(modifier = sizeModifier) {
                        definition.search?.let { searchConfig ->
                            MelodySearchBar(
                                config = searchConfig,
                                screenState = screenState,
                                luaVM = luaVM
                            )
                        }

                        Box(modifier = Modifier.weight(1f)) {
                            when (wrapper) {
                                "scroll" -> {
                                    Column(
                                        modifier = Modifier.fillMaxSize()
                                            .verticalScroll(rememberScrollState())
                                            .then(insetModifier),
                                        horizontalAlignment = Alignment.Start
                                    ) {
                                        ComponentRenderer(components = definition.body ?: emptyList())
                                    }
                                }

                                "form" -> {
                                    CompositionLocalProvider(LocalIsInFormContext provides true) {
                                        Column(
                                            modifier = Modifier.fillMaxSize()
                                                .verticalScroll(rememberScrollState())
                                                .then(insetModifier),
                                            horizontalAlignment = Alignment.Start
                                        ) {
                                            ComponentRenderer(
                                                components = definition.body ?: emptyList()
                                            )
                                        }
                                    }
                                }

                                else -> {
                                    Column(
                                        modifier = Modifier.fillMaxSize()
                                            .then(insetModifier),
                                        horizontalAlignment = Alignment.Start
                                    ) {
                                        ComponentRenderer(components = definition.body ?: emptyList())
                                    }
                                }
                            }

                            if (isLoading && !hasRefresh) {
                                CircularProgressIndicator(
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

internal fun registerMelodyFunctions(
    vm: LuaVM,
    navigator: Navigator,
    rootNavigator: Navigator?,
    store: com.melody.runtime.state.MelodyStore,
    eventBus: com.melody.runtime.state.MelodyEventBus,
    tabCoordinator: com.melody.runtime.navigation.TabCoordinator?,
    presentation: PresentationCoordinator,
    melodyDismiss: (() -> Unit)?,
    context: android.content.Context,
    onTitleChange: ((String) -> Unit)?
) {
    vm.registerMelodyFunction("navigate") { args ->
        val path = args.firstOrNull()?.stringValue
        if (path != null) {
            if (args.size >= 2) {
                args[1].tableValue?.let { navigator.navigationProps[path] = it }
            }
            navigator.navigate(path)
        }
        LuaValue.Nil
    }

    val globalNav = rootNavigator ?: navigator
    vm.registerMelodyFunction("replace") { args ->
        val path = args.firstOrNull()?.stringValue
        if (path != null) {
            val isLocal = args.getOrNull(1)?.tableValue?.get("local")?.boolValue == true
            if (isLocal) navigator.replace(path) else globalNav.replace(path)
        }
        LuaValue.Nil
    }

    vm.registerMelodyFunction("goBack") { _ ->
        navigator.goBack()
        LuaValue.Nil
    }

    vm.registerMelodyFunction("switchTab") { args ->
        args.firstOrNull()?.stringValue?.let { tabCoordinator?.switchTab(it) }
        LuaValue.Nil
    }

    vm.registerMelodyFunction("alert") { args ->
        val title = args.firstOrNull()?.stringValue ?: ""
        val message = args.getOrNull(1)?.stringValue
        val buttonsArray = (args.getOrNull(2) as? LuaValue.ArrayVal)?.value ?: emptyList()

        val buttons = buttonsArray.mapNotNull { entry ->
            val dict = entry.tableValue ?: return@mapNotNull null
            MelodyAlertButton(
                title = dict["title"]?.stringValue ?: dict["text"]?.stringValue ?: "OK",
                style = dict["style"]?.stringValue,
                onTap = dict["onTap"]?.stringValue ?: dict["action"]?.stringValue
            )
        }.ifEmpty { listOf(MelodyAlertButton(title = "OK")) }

        presentation.alert.value = MelodyAlertConfig(title, message, buttons)
        LuaValue.Nil
    }

    vm.registerMelodyFunction("sheet") { args ->
        val path = args.firstOrNull()?.stringValue ?: return@registerMelodyFunction LuaValue.Nil
        val opts = args.getOrNull(1)?.tableValue
        presentation.sheet.value = MelodySheetConfig(
            screenPath = path,
            detent = opts?.get("detent")?.stringValue,
            style = opts?.get("style")?.stringValue,
            showsToolbar = opts?.get("showsToolbar")?.boolValue
        )
        LuaValue.Nil
    }

    melodyDismiss?.let { dismiss ->
        vm.registerMelodyFunction("dismiss") { _ ->
            dismiss()
            LuaValue.Nil
        }
    }

    vm.registerMelodyFunction("storeSet") { args ->
        if (args.size >= 2) args[0].stringValue?.let { store.set(it, args[1]) }
        LuaValue.Nil
    }

    vm.registerMelodyFunction("storeSave") { args ->
        if (args.size >= 2) args[0].stringValue?.let { store.save(it, args[1]) }
        LuaValue.Nil
    }

    vm.registerMelodyFunction("storeGet") { args ->
        args.firstOrNull()?.stringValue?.let { store.get(it) } ?: LuaValue.Nil
    }

    vm.registerMelodyFunction("trustHost") { args ->
        args.firstOrNull()?.stringValue?.let { MelodyHTTP.trustHost(it) }
        LuaValue.Nil
    }

    vm.registerMelodyFunction("clearCookies") { _ ->
        LuaValue.Nil
    }

    vm.registerMelodyFunction("copyToClipboard") { args ->
        args.firstOrNull()?.stringValue?.let { text ->
            val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            clipboard.setPrimaryClip(android.content.ClipData.newPlainText("Melody", text))
        }
        LuaValue.Nil
    }

    vm.registerMelodyFunction("setTitle") { args ->
        args.firstOrNull()?.stringValue?.let { onTitleChange?.invoke(it) }
        LuaValue.Nil
    }
}

private fun registerWebSocketFunctions(
    vm: LuaVM,
    webSockets: MutableMap<Int, MelodyWebSocket>,
    nextWsId: MutableIntState
) {
    vm.registerMelodyFunction("_ws_connect") { args ->
        val urlString = args.firstOrNull()?.stringValue ?: return@registerMelodyFunction LuaValue.Nil
        val id = nextWsId.intValue
        nextWsId.intValue = id + 1

        val ws = MelodyWebSocket()
        webSockets[id] = ws

        val headers = args.getOrNull(1)?.tableValue?.mapValues { it.value.stringValue ?: "" }

        ws.onOpen = {
            vm.dispatchEvent("_ws:$id:open", LuaValue.Nil)
        }
        ws.onMessage = { text ->
            val data: LuaValue = try {
                val json = org.json.JSONObject(text)
                MelodyHTTP.jsonToLuaValue(json)
            } catch (_: Exception) {
                try {
                    val jsonArray = org.json.JSONArray(text)
                    MelodyHTTP.jsonToLuaValue(jsonArray)
                } catch (_: Exception) {
                    LuaValue.StringVal(text)
                }
            }
            vm.dispatchEvent("_ws:$id:message", data)
        }
        ws.onError = { errorMsg ->
            vm.dispatchEvent("_ws:$id:error", LuaValue.StringVal(errorMsg))
        }
        ws.onClose = { code, reason ->
            vm.dispatchEvent("_ws:$id:close", LuaValue.TableVal(mapOf(
                "code" to LuaValue.NumberVal(code.toDouble()),
                "reason" to LuaValue.StringVal(reason ?: "")
            )))
            webSockets.remove(id)
        }

        ws.connect(urlString, headers)
        LuaValue.NumberVal(id.toDouble())
    }

    vm.registerMelodyFunction("_ws_send") { args ->
        val id = args.firstOrNull()?.numberValue?.toInt() ?: return@registerMelodyFunction LuaValue.Nil
        val ws = webSockets[id] ?: return@registerMelodyFunction LuaValue.Nil

        when (val payload = args.getOrNull(1)) {
            is LuaValue.StringVal -> ws.send(payload.value)
            is LuaValue.TableVal, is LuaValue.ArrayVal -> {
                if (payload != null) {
                    ws.send(MelodyHTTP.luaValueToJson(payload))
                }
            }
            else -> {}
        }
        LuaValue.Nil
    }

    vm.registerMelodyFunction("_ws_close") { args ->
        val id = args.firstOrNull()?.numberValue?.toInt() ?: return@registerMelodyFunction LuaValue.Nil
        val ws = webSockets[id] ?: return@registerMelodyFunction LuaValue.Nil

        val code = args.getOrNull(1)?.numberValue?.toInt() ?: 1000
        val reason = args.getOrNull(2)?.stringValue
        ws.close(code, reason)
        webSockets.remove(id)
        LuaValue.Nil
    }

    vm.execute("""
        _melody_ws_objects = {}
        melody.wsConnect = function(url, options)
            local headers = options and options.headers or nil
            local id = melody._ws_connect(url, headers)
            if not id then return nil end
            local ws = { id = id }
            _melody_ws_objects[id] = ws

            function ws:on(event, callback)
                melody.on("_ws:" .. self.id .. ":" .. event, callback)
            end
            function ws:off(event, callback)
                melody.off("_ws:" .. self.id .. ":" .. event, callback)
            end
            function ws:send(data)
                melody._ws_send(self.id, data)
            end
            function ws:close(code, reason)
                for _, e in ipairs({"open", "message", "error", "close"}) do
                    melody.off("_ws:" .. self.id .. ":" .. e)
                end
                melody._ws_close(self.id, code or 1000, reason or "")
                _melody_ws_objects[self.id] = nil
            end
            return ws
        end
    """.trimIndent())
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MelodySearchBar(
    config: SearchConfig,
    screenState: ScreenState,
    luaVM: LuaVM?
) {
    var searchText by remember { mutableStateOf("") }

    DockedSearchBar(
        inputField = {
            SearchBarDefaults.InputField(
                query = searchText,
                onQueryChange = { newValue ->
                    searchText = newValue
                    screenState.set(config.stateKey, LuaValue.StringVal(newValue))
                },
                onSearch = {
                    config.onSubmit?.let { script ->
                        luaVM?.setState(config.stateKey, LuaValue.StringVal(searchText))
                        luaVM?.executeAsync(script) { result ->
                            result.onFailure { e ->
                                Log.e("Melody", "Search submit error: ${e.message}")
                            }
                        }
                    }
                },
                expanded = false,
                onExpandedChange = {},
                placeholder = { Text(config.prompt ?: "Search") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search") }
            )
        },
        expanded = false,
        onExpandedChange = {},
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {}
}

@Composable
private fun ErrorOverlay(message: String, screenId: String) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("Error", style = MaterialTheme.typography.headlineMedium, color = Color.White)
        Spacer(modifier = Modifier.height(8.dp))
        Text(message, color = Color.White.copy(alpha = 0.9f))
        Spacer(modifier = Modifier.height(4.dp))
        Text("Screen: $screenId", color = Color.White.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodySmall)
    }
}
