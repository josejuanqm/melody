package com.melody.core.schema

import kotlinx.serialization.Serializable

@Serializable
data class CustomComponentDefinition(
    val name: String? = null,
    val props: Map<String, StateValue>? = null,
    val body: List<ComponentDefinition>
)

@Serializable
data class AppDefinition(
    val app: AppConfig,
    val screens: MutableList<ScreenDefinition> = mutableListOf(),
    var components: MutableMap<String, CustomComponentDefinition>? = null
)

@Serializable
data class AppConfig(
    val name: String,
    val id: String? = null,
    val theme: ThemeConfig? = null,
    val window: WindowConfig? = null,
    val lua: String? = null,
    /** Plugin declarations: name → git URL. Used by the CLI; parsed but not used at runtime. */
    val plugins: Map<String, String>? = null
)

@Serializable
data class ThemeModeOverride(
    val primary: String? = null,
    val secondary: String? = null,
    val background: String? = null,
    val colors: Map<String, String>? = null
)

@Serializable
data class ThemeConfig(
    val primary: String? = null,
    val secondary: String? = null,
    val background: String? = null,
    val colorScheme: String? = null,
    val colors: Map<String, String>? = null,
    val dark: ThemeModeOverride? = null,
    val light: ThemeModeOverride? = null
)

@Serializable
data class TabDefinition(
    val id: String,
    val title: String,
    val icon: String,
    val screen: String,
    val platforms: List<String>? = null,
    val group: String? = null,
    /** Controls dynamic visibility. Can be a literal bool or a `{{ Lua expression }}`. */
    @Serializable(with = ValueBoolSerializer::class)
    val visible: Value<Boolean>? = null
)

@Serializable
data class WindowConfig(
    val minWidth: Double? = null,
    val minHeight: Double? = null,
    val idealWidth: Double? = null,
    val idealHeight: Double? = null
)
