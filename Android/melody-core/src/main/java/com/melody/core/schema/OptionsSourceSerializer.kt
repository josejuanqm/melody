package com.melody.core.schema

import com.charleskorn.kaml.*
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.InternalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.SerialKind
import kotlinx.serialization.descriptors.buildSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

object OptionsSourceSerializer : KSerializer<OptionsSource> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor = buildSerialDescriptor("OptionsSource", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: OptionsSource) {
        when (value) {
            is OptionsSource.Static -> encoder.encodeSerializableValue(
                ListSerializer(OptionDefinition.serializer()), value.options
            )
            is OptionsSource.Expression -> encoder.encodeString(value.expr)
        }
    }

    override fun deserialize(decoder: Decoder): OptionsSource {
        val input = decoder as? YamlInput
            ?: return OptionsSource.Expression(decoder.decodeString())

        return when (val node = input.node) {
            is YamlScalar -> OptionsSource.Expression(node.content)
            is YamlList -> {
                val options = node.items.map { item ->
                    val map = item as? YamlMap
                        ?: return@map OptionDefinition(label = "", value = "")
                    val label = map.stringAt("label") ?: ""
                    val value = map.stringAt("value") ?: ""
                    OptionDefinition(label = label, value = value)
                }
                OptionsSource.Static(options)
            }
            else -> OptionsSource.Static(emptyList())
        }
    }

    private fun YamlMap.stringAt(key: String): String? {
        return entries.entries.firstOrNull { it.key.content == key }
            ?.value?.let { (it as? YamlScalar)?.content }
    }
}
