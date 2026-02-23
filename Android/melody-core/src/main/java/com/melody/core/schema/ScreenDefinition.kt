package com.melody.core.schema

import kotlinx.serialization.Serializable

@Serializable
data class SearchConfig(
    val stateKey: String,
    val prompt: String? = null,
    val onSubmit: String? = null,
    val placement: String? = null,
    val minimized: Boolean? = null
)

@Serializable
data class ContentInset(
    val top: Double? = null,
    val bottom: Double? = null,
    val leading: Double? = null,
    val trailing: Double? = null,
    val vertical: Double? = null,
    val horizontal: Double? = null
) {
    val resolvedTop: Double get() = top ?: vertical ?: 0.0
    val resolvedBottom: Double get() = bottom ?: vertical ?: 0.0
    val resolvedLeading: Double get() = leading ?: horizontal ?: 0.0
    val resolvedTrailing: Double get() = trailing ?: horizontal ?: 0.0
}

@Serializable
data class ScreenDefinition(
    val id: String,
    val path: String,
    val title: String? = null,
    val titleDisplayMode: String? = null,
    val state: Map<String, StateValue>? = null,
    val onMount: String? = null,
    val body: List<ComponentDefinition>? = null,
    val tabs: List<TabDefinition>? = null,
    val tabStyle: String? = null,
    val toolbar: List<ComponentDefinition>? = null,
    val titleMenu: List<ComponentDefinition>? = null,
    val titleMenuBuilder: String? = null,
    val search: SearchConfig? = null,
    val scrollEnabled: Boolean? = true,
    val wrapper: String? = null,
    val formStyle: String? = null,
    val contentInset: ContentInset? = null,
    val onRefresh: String? = null
)
