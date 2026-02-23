package com.melody.core.schema

import com.charleskorn.kaml.*
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

@Serializable
data class ShadowStyle(
    val x: Double? = null,
    val y: Double? = null,
    val blur: Double? = null,
    val color: String? = null
)

/**
 * Style properties for components.
 * Uses a custom serializer to handle "full" → -1 for size values
 * and kaml YAML decoding.
 */
@Serializable(with = ComponentStyleSerializer::class)
data class ComponentStyle(
    // Value<Double> properties -- accept both literals and {{ expressions }}
    var fontSize: Value<Double>? = null,
    var padding: Value<Double>? = null,
    var paddingTop: Value<Double>? = null,
    var paddingBottom: Value<Double>? = null,
    var paddingLeft: Value<Double>? = null,
    var paddingRight: Value<Double>? = null,
    var paddingHorizontal: Value<Double>? = null,
    var paddingVertical: Value<Double>? = null,
    var margin: Value<Double>? = null,
    var marginTop: Value<Double>? = null,
    var marginBottom: Value<Double>? = null,
    var marginLeft: Value<Double>? = null,
    var marginRight: Value<Double>? = null,
    var marginHorizontal: Value<Double>? = null,
    var marginVertical: Value<Double>? = null,
    var borderRadius: Value<Double>? = null,
    var borderWidth: Value<Double>? = null,
    var width: Value<Double>? = null,
    var height: Value<Double>? = null,
    var minWidth: Value<Double>? = null,
    var minHeight: Value<Double>? = null,
    var maxWidth: Value<Double>? = null,
    var maxHeight: Value<Double>? = null,
    var spacing: Value<Double>? = null,
    var opacity: Value<Double>? = null,
    var cornerRadius: Value<Double>? = null,
    var scale: Value<Double>? = null,
    var rotation: Value<Double>? = null,
    var aspectRatio: Value<Double>? = null,
    var layoutPriority: Value<Double>? = null,

    // Value<String> properties
    var color: Value<String>? = null,
    var backgroundColor: Value<String>? = null,
    var borderColor: Value<String>? = null,

    // Value<ViewAlignment>
    var alignment: Value<ViewAlignment>? = null,

    // Value<Int>
    var lineLimit: Value<Int>? = null,

    // Always-literal properties
    var fontWeight: String? = null,
    var fontDesign: String? = null,
    var shadow: ShadowStyle? = null,
    var animation: String? = null,
    var contentMode: String? = null,
    var overflow: String? = null
)

object ComponentStyleSerializer : KSerializer<ComponentStyle> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("ComponentStyle")

    override fun serialize(encoder: Encoder, value: ComponentStyle) {
        encoder.encodeString("[style]")
    }

    override fun deserialize(decoder: Decoder): ComponentStyle {
        val input = decoder as? YamlInput
            ?: return ComponentStyle()
        val map = input.node as? YamlMap ?: return ComponentStyle()

        val style = ComponentStyle()

        for ((keyNode, valueNode) in map.entries) {
            val key = keyNode.content
            val scalar = (valueNode as? YamlScalar)?.content

            when (key) {
                // Value<Double> numeric properties
                "fontSize" -> style.fontSize = scalar?.let { parseDoubleValue(it) }
                "padding" -> style.padding = scalar?.let { parseDoubleValue(it) }
                "paddingTop" -> style.paddingTop = scalar?.let { parseDoubleValue(it) }
                "paddingBottom" -> style.paddingBottom = scalar?.let { parseDoubleValue(it) }
                "paddingLeft" -> style.paddingLeft = scalar?.let { parseDoubleValue(it) }
                "paddingRight" -> style.paddingRight = scalar?.let { parseDoubleValue(it) }
                "paddingHorizontal" -> style.paddingHorizontal = scalar?.let { parseDoubleValue(it) }
                "paddingVertical" -> style.paddingVertical = scalar?.let { parseDoubleValue(it) }
                "margin" -> style.margin = scalar?.let { parseDoubleValue(it) }
                "marginTop" -> style.marginTop = scalar?.let { parseDoubleValue(it) }
                "marginBottom" -> style.marginBottom = scalar?.let { parseDoubleValue(it) }
                "marginLeft" -> style.marginLeft = scalar?.let { parseDoubleValue(it) }
                "marginRight" -> style.marginRight = scalar?.let { parseDoubleValue(it) }
                "marginHorizontal" -> style.marginHorizontal = scalar?.let { parseDoubleValue(it) }
                "marginVertical" -> style.marginVertical = scalar?.let { parseDoubleValue(it) }
                "borderRadius" -> style.borderRadius = scalar?.let { parseDoubleValue(it) }
                "borderWidth" -> style.borderWidth = scalar?.let { parseDoubleValue(it) }
                "spacing" -> style.spacing = scalar?.let { parseDoubleValue(it) }
                "opacity" -> style.opacity = scalar?.let { parseDoubleValue(it) }
                "cornerRadius" -> style.cornerRadius = scalar?.let { parseDoubleValue(it) }
                "scale" -> style.scale = scalar?.let { parseDoubleValue(it) }
                "rotation" -> style.rotation = scalar?.let { parseDoubleValue(it) }
                "aspectRatio" -> style.aspectRatio = scalar?.let { parseDoubleValue(it) }
                "layoutPriority" -> style.layoutPriority = scalar?.let { parseDoubleValue(it) }

                // Size properties (support "full" -> -1.0)
                "width" -> style.width = scalar?.let { parseSizeValue(it) }
                "height" -> style.height = scalar?.let { parseSizeValue(it) }
                "minWidth" -> style.minWidth = scalar?.let { parseSizeValue(it) }
                "minHeight" -> style.minHeight = scalar?.let { parseSizeValue(it) }
                "maxWidth" -> style.maxWidth = scalar?.let { parseSizeValue(it) }
                "maxHeight" -> style.maxHeight = scalar?.let { parseSizeValue(it) }

                // Value<String> color properties
                "color" -> style.color = scalar?.let { parseStringValue(it) }
                "backgroundColor" -> style.backgroundColor = scalar?.let { parseStringValue(it) }
                "borderColor" -> style.borderColor = scalar?.let { parseStringValue(it) }

                // Value<ViewAlignment>
                "alignment" -> style.alignment = scalar?.let { parseAlignmentValue(it) }

                // Value<Int>
                "lineLimit" -> style.lineLimit = scalar?.let { parseIntValue(it) }

                // Always-literal properties
                "fontWeight" -> style.fontWeight = scalar
                "fontDesign" -> style.fontDesign = scalar
                "animation" -> style.animation = scalar
                "contentMode" -> style.contentMode = scalar
                "overflow" -> style.overflow = scalar

                "shadow" -> {
                    val shadowMap = valueNode as? YamlMap
                    if (shadowMap != null) {
                        style.shadow = ShadowStyle(
                            x = shadowMap.stringAt("x")?.toDoubleOrNull(),
                            y = shadowMap.stringAt("y")?.toDoubleOrNull(),
                            blur = shadowMap.stringAt("blur")?.toDoubleOrNull(),
                            color = shadowMap.stringAt("color")
                        )
                    }
                }
            }
        }

        return style
    }

    /** Parse a numeric value or {{ expression }}. */
    private fun parseDoubleValue(content: String): Value<Double>? {
        Value.extractExpression(content)?.let { return Value.Expression(it) }
        return content.toDoubleOrNull()?.let { Value.Literal(it) }
    }

    /** Parse a size value: number, "full" -> -1.0, or {{ expression }}. */
    private fun parseSizeValue(content: String): Value<Double>? {
        Value.extractExpression(content)?.let { return Value.Expression(it) }
        if (content.lowercase() == "full") return Value.Literal(-1.0)
        return content.toDoubleOrNull()?.let { Value.Literal(it) }
    }

    /** Parse a string value or {{ expression }}. */
    private fun parseStringValue(content: String): Value<String> {
        Value.extractExpression(content)?.let { return Value.Expression(it) }
        return Value.Literal(content)
    }

    /** Parse an alignment value or {{ expression }}. */
    private fun parseAlignmentValue(content: String): Value<ViewAlignment> {
        Value.extractExpression(content)?.let { return Value.Expression(it) }
        return Value.Literal(ViewAlignment.from(content))
    }

    /** Parse an int value or {{ expression }}. */
    private fun parseIntValue(content: String): Value<Int>? {
        Value.extractExpression(content)?.let { return Value.Expression(it) }
        content.toIntOrNull()?.let { return Value.Literal(it) }
        content.toDoubleOrNull()?.toInt()?.let { return Value.Literal(it) }
        return null
    }

    private fun YamlMap.stringAt(key: String): String? {
        return entries.entries.firstOrNull { it.key.content == key }
            ?.value?.let { (it as? YamlScalar)?.content }
    }
}
