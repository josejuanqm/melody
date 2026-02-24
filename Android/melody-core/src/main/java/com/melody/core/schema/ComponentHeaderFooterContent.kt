package com.melody.core.schema

import com.charleskorn.kaml.*
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.InternalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.SerialKind
import kotlinx.serialization.descriptors.buildSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/**
 * Header/Footer content for sections.
 * Can be either a string or an array of ComponentDefinitions.
 * Mirrors iOS `ComponentHeaderFooterContent`.
 */
@Serializable(with = ComponentHeaderFooterContentSerializer::class)
sealed class ComponentHeaderFooterContent {
    data class Text(val value: Value<String>?) : ComponentHeaderFooterContent()
    data class Components(val definitions: List<ComponentDefinition>) : ComponentHeaderFooterContent()

    val textValue: String?
        get() = (this as? Text)?.value?.literalValue

    val expressionValue: String?
        get() = (this as? Text)?.value?.literalValue

    val value: Value<String>?
        get() = (this as? Text)?.value

    val componentDefinitions: List<ComponentDefinition>?
        get() = (this as? Components)?.definitions

    companion object {
        fun from(rawValue: Value<String>): ComponentHeaderFooterContent {
            return Text(rawValue)
        }
    }
}

object ComponentHeaderFooterContentSerializer : KSerializer<ComponentHeaderFooterContent> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor = buildSerialDescriptor("ComponentHeaderFooterContent", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: ComponentHeaderFooterContent) {
        when (value) {
            is ComponentHeaderFooterContent.Text -> encoder.encodeString(value.textValue ?: "")
            is ComponentHeaderFooterContent.Components -> encoder.encodeSerializableValue(
                ListSerializer(ComponentDefinition.serializer()), value.definitions
            )
        }
    }

    override fun deserialize(decoder: Decoder): ComponentHeaderFooterContent {
        val input = decoder as? YamlInput
            ?: return ComponentHeaderFooterContent.Text(ValueStringSerializer.deserialize(decoder))

        return when (val node = input.node) {
            is YamlScalar -> ComponentHeaderFooterContent.Text(Value.fromString(node.content))
            is YamlList -> {
                val yamlInput = decoder as YamlInput
                val definitions = yamlInput.decodeSerializableValue(
                    ListSerializer(ComponentDefinition.serializer())
                )
                ComponentHeaderFooterContent.Components(definitions)
            }
            else -> ComponentHeaderFooterContent.Text(Value.fromString(""))
        }
    }
}
