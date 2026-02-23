package com.melody.runtime.renderer

import androidx.compose.runtime.compositionLocalOf
import com.melody.core.schema.CustomComponentDefinition
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.navigation.Navigator
import com.melody.runtime.navigation.TabCoordinator
import com.melody.runtime.plugin.MelodyPluginRegistry
import com.melody.runtime.state.LocalState
import com.melody.runtime.state.MelodyEventBus
import com.melody.runtime.state.MelodyStore
import com.melody.runtime.state.ScreenState
import com.melody.runtime.state.ScreenVMStore

/**
 * CompositionLocal providers — replaces SwiftUI @Environment keys.
 */
val LocalNavigator = compositionLocalOf<Navigator> { error("No navigator") }
val LocalRootNavigator = compositionLocalOf<Navigator?> { null }
val LocalMelodyStore = compositionLocalOf<MelodyStore> { error("No store") }
val LocalEventBus = compositionLocalOf<MelodyEventBus> { error("No event bus") }
val LocalLuaVM = compositionLocalOf<LuaVM?> { null }
val LocalScreenState = compositionLocalOf { ScreenState() }
val LocalLocalState = compositionLocalOf<LocalState?> { null }
val LocalThemeColors = compositionLocalOf<Map<String, String>> { emptyMap() }
val LocalCustomComponents = compositionLocalOf<Map<String, CustomComponentDefinition>> { emptyMap() }
val LocalComponentProps = compositionLocalOf<Map<String, LuaValue>?> { null }
val LocalAppLuaPrelude = compositionLocalOf<String?> { null }
val LocalTabCoordinator = compositionLocalOf<TabCoordinator?> { null }
val LocalMelodyDismiss = compositionLocalOf<(() -> Unit)?> { null }
val LocalPluginRegistry = compositionLocalOf<MelodyPluginRegistry?> { null }
val LocalAssetBaseURL = compositionLocalOf<String?> { null }
val LocalScreenVMStore = compositionLocalOf<ScreenVMStore> { error("No ScreenVMStore") }
