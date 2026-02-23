package com.melody.core.schema

/**
 * Layout direction for stacks and containers.
 * Mirrors iOS `DirectionAxis`.
 */
enum class DirectionAxis(val value: String) {
    Horizontal("horizontal"),
    Vertical("vertical"),
    Stacked("stacked");

    companion object {
        fun from(rawValue: String): DirectionAxis {
            return when (rawValue.lowercase()) {
                "horizontal" -> Horizontal
                "vertical" -> Vertical
                "stacked", "z" -> Stacked
                else -> Vertical
            }
        }
    }
}
