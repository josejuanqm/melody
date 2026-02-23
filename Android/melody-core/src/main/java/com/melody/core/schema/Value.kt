package com.melody.core.schema

import com.charleskorn.kaml.YamlInput
import com.charleskorn.kaml.YamlScalar
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.InternalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.SerialKind
import kotlinx.serialization.descriptors.buildSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/**
 * A property value that is either a literal or a `{{ Lua expression }}`.
 * Mirrors iOS `Value<T>`.
 */
sealed class Value<out T> {
    data class Literal<T>(val value: T) : Value<T>()
    data class Expression(val expr: String) : Value<Nothing>()

    val literalValue: T?
        get() = (this as? Literal)?.value

    val expressionValue: String?
        get() = (this as? Expression)?.expr

    companion object {
        /** Extracts the inner expression from `{{ ... }}` delimiters, or returns null. */
        fun extractExpression(string: String): String? {
            val trimmed = string.trim()
            if (!trimmed.startsWith("{{") || !trimmed.endsWith("}}")) return null
            return trimmed.drop(2).dropLast(2).trim()
        }

        /** Parses a string that may contain `{{ expr }}` into a Value<String>. */
        fun fromString(string: String): Value<String> {
            val expr = extractExpression(string)
            return if (expr != null) Expression(expr) else Literal(string)
        }

        /** Parses a string into a Value<Double>. Handles "full" -> -1.0 and {{ expr }}. */
        fun fromDouble(string: String): Value<Double>? {
            val expr = extractExpression(string)
            if (expr != null) return Expression(expr)
            if (string.lowercase() == "full") return Literal(-1.0)
            return string.toDoubleOrNull()?.let { Literal(it) }
        }
    }
}

// MARK: - Convenience extensions for Optional<Value<T>>

val Value<Double>?.resolved: Double?
    get() = this?.literalValue

val Value<String>?.resolved: String?
    get() = this?.literalValue

val Value<Int>?.resolved: Int?
    get() = this?.literalValue

val Value<Boolean>?.resolved: Boolean?
    get() = this?.literalValue

val Value<DirectionAxis>?.resolved: DirectionAxis?
    get() = this?.literalValue

val Value<ViewAlignment>?.resolved: ViewAlignment?
    get() = this?.literalValue

// MARK: - Type-specific serializers

/**
 * Decodes a string, checks for {{ }} -> Expression or Literal<String>.
 */
object ValueStringSerializer : KSerializer<Value<String>?> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("ValueString", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: Value<String>?) {
        when (value) {
            is Value.Literal -> encoder.encodeString(value.value)
            is Value.Expression -> encoder.encodeString("{{ ${value.expr} }}")
            null -> {}
        }
    }

    override fun deserialize(decoder: Decoder): Value<String>? {
        val str = try {
            val input = decoder as? YamlInput
            if (input != null) {
                (input.node as? YamlScalar)?.content
            } else {
                decoder.decodeString()
            }
        } catch (_: Exception) { null } ?: return null
        return Value.fromString(str)
    }
}

/**
 * Decodes a boolean value, or a string for {{ }} -> Expression.
 */
object ValueBoolSerializer : KSerializer<Value<Boolean>?> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("ValueBool", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: Value<Boolean>?) {
        when (value) {
            is Value.Literal -> encoder.encodeBoolean(value.value)
            is Value.Expression -> encoder.encodeString("{{ ${value.expr} }}")
            null -> {}
        }
    }

    override fun deserialize(decoder: Decoder): Value<Boolean>? {
        val input = decoder as? YamlInput
        val content = if (input != null) {
            (input.node as? YamlScalar)?.content
        } else {
            try { decoder.decodeString() } catch (_: Exception) { null }
        } ?: return null

        // Check for expression
        Value.extractExpression(content)?.let { return Value.Expression(it) }

        // Try boolean
        return when (content.lowercase()) {
            "true" -> Value.Literal(true)
            "false" -> Value.Literal(false)
            else -> null
        }
    }
}

/**
 * Decodes a double value, or a string for {{ }} / "full" -> Expression/Literal.
 */
object ValueDoubleSerializer : KSerializer<Value<Double>?> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("ValueDouble", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: Value<Double>?) {
        when (value) {
            is Value.Literal -> encoder.encodeDouble(value.value)
            is Value.Expression -> encoder.encodeString("{{ ${value.expr} }}")
            null -> {}
        }
    }

    override fun deserialize(decoder: Decoder): Value<Double>? {
        val input = decoder as? YamlInput
        val content = if (input != null) {
            (input.node as? YamlScalar)?.content
        } else {
            try { decoder.decodeString() } catch (_: Exception) { null }
        } ?: return null

        return Value.fromDouble(content)
    }
}

/**
 * Decodes an int value, or a string for {{ }} -> Expression.
 */
object ValueIntSerializer : KSerializer<Value<Int>?> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("ValueInt", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: Value<Int>?) {
        when (value) {
            is Value.Literal -> encoder.encodeInt(value.value)
            is Value.Expression -> encoder.encodeString("{{ ${value.expr} }}")
            null -> {}
        }
    }

    override fun deserialize(decoder: Decoder): Value<Int>? {
        val input = decoder as? YamlInput
        val content = if (input != null) {
            (input.node as? YamlScalar)?.content
        } else {
            try { decoder.decodeString() } catch (_: Exception) { null }
        } ?: return null

        Value.extractExpression(content)?.let { return Value.Expression(it) }
        content.toIntOrNull()?.let { return Value.Literal(it) }
        content.toDoubleOrNull()?.toInt()?.let { return Value.Literal(it) }
        return null
    }
}

/**
 * Decodes a DirectionAxis value, or a string for {{ }} -> Expression.
 */
object ValueDirectionAxisSerializer : KSerializer<Value<DirectionAxis>?> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("ValueDirectionAxis", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: Value<DirectionAxis>?) {
        when (value) {
            is Value.Literal -> encoder.encodeString(value.value.value)
            is Value.Expression -> encoder.encodeString("{{ ${value.expr} }}")
            null -> {}
        }
    }

    override fun deserialize(decoder: Decoder): Value<DirectionAxis>? {
        val input = decoder as? YamlInput
        val content = if (input != null) {
            (input.node as? YamlScalar)?.content
        } else {
            try { decoder.decodeString() } catch (_: Exception) { null }
        } ?: return null

        Value.extractExpression(content)?.let { return Value.Expression(it) }
        return Value.Literal(DirectionAxis.from(content))
    }
}

/**
 * Decodes a ViewAlignment value, or a string for {{ }} -> Expression.
 */
object ValueViewAlignmentSerializer : KSerializer<Value<ViewAlignment>?> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("ValueViewAlignment", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: Value<ViewAlignment>?) {
        when (value) {
            is Value.Literal -> encoder.encodeString(value.value.value)
            is Value.Expression -> encoder.encodeString("{{ ${value.expr} }}")
            null -> {}
        }
    }

    override fun deserialize(decoder: Decoder): Value<ViewAlignment>? {
        val input = decoder as? YamlInput
        val content = if (input != null) {
            (input.node as? YamlScalar)?.content
        } else {
            try { decoder.decodeString() } catch (_: Exception) { null }
        } ?: return null

        Value.extractExpression(content)?.let { return Value.Expression(it) }
        return Value.Literal(ViewAlignment.from(content))
    }
}

/**
 * Serializer for Map<String, Value<String>> used by ComponentDefinition.props.
 */
object ValueStringMapSerializer : KSerializer<Map<String, Value<String>>?> {
    @OptIn(InternalSerializationApi::class, ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor =
        buildSerialDescriptor("ValueStringMap", SerialKind.CONTEXTUAL)

    override fun serialize(encoder: Encoder, value: Map<String, Value<String>>?) {
        // Not needed for YAML parsing
    }

    override fun deserialize(decoder: Decoder): Map<String, Value<String>>? {
        val input = decoder as? YamlInput ?: return null
        val map = input.node as? com.charleskorn.kaml.YamlMap ?: return null
        val result = mutableMapOf<String, Value<String>>()
        for ((keyNode, valueNode) in map.entries) {
            val key = keyNode.content
            val scalar = (valueNode as? YamlScalar)?.content ?: continue
            result[key] = Value.fromString(scalar)
        }
        return if (result.isEmpty()) null else result
    }
}
