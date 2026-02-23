package com.melody.core.schema

import kotlinx.serialization.Serializable

/** Schema for a plugin's `plugin.yaml` manifest file. */
@Serializable
data class PluginManifest(
    val name: String,
    val version: String? = null,
    val description: String? = null,
    val ios: PlatformConfig? = null,
    val android: PlatformConfig? = null,
    val lua: List<String>? = null
) {
    @Serializable
    data class PlatformConfig(
        val sources: List<String>,
        val frameworks: List<String>? = null,
        val dependencies: List<String>? = null
    )
}
