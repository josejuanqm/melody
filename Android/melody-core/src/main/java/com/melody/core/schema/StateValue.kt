package com.melody.core.schema

import com.charleskorn.kaml.*
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.InternalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.SerialKind
import kotlinx.serialization.descriptors.buildSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/**
 * A state value that can be a string, number, bool, null, or nested structure.
 * Uses a custom serializer for polymorphic YAML decoding via kaml.
 */
@Serializable(with = StateValueSerializer::class)
sealed class StateValue {
    data class StringVal(val value: String) : StateValue()
    data class IntVal(val value: Int) : StateValue()
    data class DoubleVal(val value: Double) : StateValue()
    data class BoolVal(val value: Boolean) : StateValue()
    object NullVal : StateValue()
    data class ArrayVal(val value: List<StateValue>) : StateValue()
    data class DictionaryVal(val value: Map<String, StateValue>) : StateValue()
}

object StateValueSerializer : KSerializer<StateValue> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor = buildSerialDescriptor("StateValue", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: StateValue) {
        when (value) {
            is StateValue.StringVal -> encoder.encodeString(value.value)
            is StateValue.IntVal -> encoder.encodeInt(value.value)
            is StateValue.DoubleVal -> encoder.encodeDouble(value.value)
            is StateValue.BoolVal -> encoder.encodeBoolean(value.value)
            is StateValue.NullVal -> encoder.encodeString("null")
            is StateValue.ArrayVal -> encoder.encodeString("[array]")
            is StateValue.DictionaryVal -> encoder.encodeString("[dict]")
        }
    }

    override fun deserialize(decoder: Decoder): StateValue {
        val input = decoder as? YamlInput
            ?: return StateValue.StringVal(decoder.decodeString())
        return yamlNodeToStateValue(input.node)
    }

    private fun yamlNodeToStateValue(node: YamlNode): StateValue = when (node) {
        is YamlNull -> StateValue.NullVal
        is YamlScalar -> parseScalar(node.content)
        is YamlList -> StateValue.ArrayVal(node.items.map { yamlNodeToStateValue(it) })
        is YamlMap -> StateValue.DictionaryVal(
            node.entries.map { (key, value) -> key.content to yamlNodeToStateValue(value) }.toMap()
        )
        is YamlTaggedNode -> yamlNodeToStateValue(node.innerNode)
        else -> StateValue.NullVal
    }

    private fun parseScalar(content: String): StateValue {
        if (content == "null" || content == "~") return StateValue.NullVal
        if (content == "true") return StateValue.BoolVal(true)
        if (content == "false") return StateValue.BoolVal(false)
        content.toIntOrNull()?.let { return StateValue.IntVal(it) }
        content.toDoubleOrNull()?.let { return StateValue.DoubleVal(it) }
        return StateValue.StringVal(content)
    }
}
