package com.melody.core.schema

import kotlinx.serialization.Serializable

@Serializable
data class MarkDefinition(
    val type: String,
    val xKey: String? = null,
    val yKey: String? = null,
    val groupKey: String? = null,
    val angleKey: String? = null,
    val innerRadius: Double? = null,
    val angularInset: Double? = null,
    val xValue: String? = null,
    val yValue: Double? = null,
    val label: String? = null,
    val xStartKey: String? = null,
    val xEndKey: String? = null,
    val yStartKey: String? = null,
    val yEndKey: String? = null,
    val interpolation: String? = null,
    val lineWidth: Double? = null,
    val cornerRadius: Double? = null,
    val symbolSize: Double? = null,
    val stacking: String? = null,
    val color: String? = null
)
