package com.melody.runtime.renderer

import android.content.Context
import android.util.Log
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.*
import com.melody.core.schema.AppDefinition
import com.melody.runtime.devclient.DevLogger
import com.melody.runtime.devclient.DevSettings
import com.melody.runtime.devclient.DevSettingsScreen
import com.melody.runtime.devclient.HotReloadClient
import com.melody.runtime.devclient.ShakeDetector
import com.melody.runtime.navigation.Navigator
import com.melody.runtime.networking.MelodyHTTP
import com.melody.runtime.plugin.MelodyPlugin
import com.melody.runtime.plugin.MelodyPluginRegistry
import com.melody.runtime.state.MelodyEventBus
import com.melody.runtime.state.MelodyStore
import com.melody.runtime.state.ScreenVMStore

/**
 * Root composable that renders an entire Melody app from an AppDefinition.
 * Port of iOS MelodyAppView.swift.
 */
@Composable
fun MelodyApp(
    appDefinition: AppDefinition,
    context: Context,
    plugins: List<MelodyPlugin> = emptyList(),
    assetBaseURL: String? = null
) {
    remember(context) {
        com.melody.runtime.engine.LuaVM.isDebugBuild =
            (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        true
    }

    var currentApp by remember { mutableStateOf(appDefinition) }
    val navigator = remember { Navigator() }
    val store = remember { MelodyStore(context) }
    val screenVMStore = remember { ScreenVMStore() }

    remember { MelodyHTTP.init(context) }
    val eventBus = remember { MelodyEventBus() }
    val pluginRegistry = remember(plugins) { MelodyPluginRegistry(plugins) }
    val isDark = isSystemInDarkTheme()

    // Dev tools
    val devSettings = remember { DevSettings(context) }
    val hotReload = remember { HotReloadClient() }
    var showDevSettings by remember { mutableStateOf(false) }

    LaunchedEffect(devSettings.hotReloadEnabled, devSettings.devServerHost, devSettings.devServerPort) {
        if (devSettings.hotReloadEnabled) {
            hotReload.disconnect()
            hotReload.connect(devSettings.devServerHost, devSettings.devServerPort)
        } else {
            hotReload.disconnect()
        }
    }

    LaunchedEffect(hotReload.reloadCount) {
        if (hotReload.reloadCount > 0) {
            hotReload.latestApp?.let { newApp ->
                currentApp = newApp
                screenVMStore.clear(eventBus)
                navigator.registerScreens(newApp.screens)
                navigator.replace("/")
            }
        }
    }

    ShakeDetector { showDevSettings = true }

    DisposableEffect(eventBus) {
        val id = eventBus.observe("showDevSettings") { showDevSettings = true }
        onDispose { eventBus.removeObserver(id) }
    }

    remember(currentApp) {
        Log.d("Melody", "Registering ${currentApp.screens.size} screens: ${currentApp.screens.map { it.id }}")
        navigator.registerScreens(currentApp.screens)
    }

    val mergedThemeColors = remember(currentApp, isDark) {
        mergeThemeColors(currentApp, isDark)
    }

    val colorScheme = when (currentApp.app.theme?.colorScheme?.lowercase()) {
        "dark" -> darkColorScheme()
        "light" -> lightColorScheme()
        else -> if (isDark) darkColorScheme() else lightColorScheme()
    }

    MaterialTheme(colorScheme = colorScheme) {
        CompositionLocalProvider(
            LocalNavigator provides navigator,
            LocalRootNavigator provides navigator,
            LocalMelodyStore provides store,
            LocalEventBus provides eventBus,
            LocalThemeColors provides mergedThemeColors,
            LocalCustomComponents provides (currentApp.components ?: emptyMap()),
            LocalAppLuaPrelude provides currentApp.app.lua,
            LocalPluginRegistry provides pluginRegistry,
            LocalAssetBaseURL provides assetBaseURL,
            LocalScreenVMStore provides screenVMStore
        ) {
            val rootScreen = navigator.screen(navigator.rootPath.value)
                ?: currentApp.screens.firstOrNull()

            Log.d("Melody", "Root screen: ${rootScreen?.id}, tabs: ${rootScreen?.tabs?.size}, path: ${navigator.rootPath.value}")

            if (rootScreen != null) {
                if (rootScreen.tabs != null) {
                    TabContainerView(definition = rootScreen)
                } else {
                    MelodyNavHost(
                        navigator = navigator,
                        rootScreen = rootScreen
                    )
                }
            }
        }

        if (showDevSettings) {
            DevSettingsScreen(
                settings = devSettings,
                hotReload = hotReload,
                onReconnect = {
                    hotReload.disconnect()
                    if (devSettings.hotReloadEnabled) {
                        hotReload.connect(devSettings.devServerHost, devSettings.devServerPort)
                    }
                },
                onDismiss = { showDevSettings = false }
            )
        }
    }
}

private fun mergeThemeColors(app: AppDefinition, isDark: Boolean): Map<String, String> {
    val colors = mutableMapOf<String, String>()

    app.app.theme?.primary?.let { colors["primary"] = it }
    app.app.theme?.secondary?.let { colors["secondary"] = it }
    app.app.theme?.background?.let { colors["background"] = it }
    app.app.theme?.colors?.let { colors.putAll(it) }

    val forcedDark = app.app.theme?.colorScheme?.lowercase() == "dark"
    val forcedLight = app.app.theme?.colorScheme?.lowercase() == "light"
    val activeIsDark = when {
        forcedDark -> true
        forcedLight -> false
        else -> isDark
    }

    val override = if (activeIsDark) app.app.theme?.dark else app.app.theme?.light
    override?.let { o ->
        o.primary?.let { colors["primary"] = it }
        o.secondary?.let { colors["secondary"] = it }
        o.background?.let { colors["background"] = it }
        o.colors?.let { colors.putAll(it) }
    }

    return colors
}
