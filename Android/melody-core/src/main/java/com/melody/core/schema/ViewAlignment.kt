package com.melody.core.schema

/**
 * Alignment for views and containers.
 * Mirrors iOS `ViewAlignment`.
 */
enum class ViewAlignment(val value: String) {
    Center("center"),
    Top("top"),
    Bottom("bottom"),
    Leading("leading"),
    Left("left"),
    Trailing("trailing"),
    Right("right"),
    TopLeading("topLeading"),
    TopLeft("topLeft"),
    TopTrailing("topTrailing"),
    TopRight("topRight"),
    BottomLeading("bottomLeading"),
    BottomLeft("bottomLeft"),
    BottomTrailing("bottomTrailing"),
    BottomRight("bottomRight");

    companion object {
        fun from(rawValue: String): ViewAlignment {
            return when (rawValue.lowercase()) {
                "center" -> Center
                "top" -> Top
                "bottom" -> Bottom
                "leading" -> Leading
                "left" -> Left
                "trailing" -> Trailing
                "right" -> Right
                "topleading" -> TopLeading
                "topleft" -> TopLeft
                "toptrailing" -> TopTrailing
                "topright" -> TopRight
                "bottomleading" -> BottomLeading
                "bottomleft" -> BottomLeft
                "bottomtrailing" -> BottomTrailing
                "bottomright" -> BottomRight
                else -> Leading
            }
        }
    }
}
