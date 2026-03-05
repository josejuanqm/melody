package com.melody.core.schema

import kotlinx.serialization.Serializable

@Serializable
data class OptionDefinition(
    val label: String,
    val value: String
)

/**
 * Options for picker/menu: either a static array or a Lua expression string.
 * Uses a custom serializer to handle polymorphic YAML.
 */
@Serializable(with = OptionsSourceSerializer::class)
sealed class OptionsSource {
    data class Static(val options: List<OptionDefinition>) : OptionsSource()
    data class Expression(val expr: String) : OptionsSource()

    val staticOptions: List<OptionDefinition>?
        get() = (this as? Static)?.options

    val expressionString: String?
        get() = (this as? Expression)?.expr

    val isEmpty: Boolean
        get() = when (this) {
            is Static -> options.isEmpty()
            is Expression -> false
        }
}

@Serializable
data class ContextMenuItem(
    val label: String = "",
    val systemImage: String? = null,
    val style: String? = null,
    val onTap: String? = null,
    val section: Boolean? = null
)

@Serializable
data class ComponentDefinition(
    val component: String,
    val id: String? = null,

    // Value<T> properties -- accept both literals and {{ expressions }}
    @Serializable(with = ValueStringSerializer::class)
    val text: Value<String>? = null,
    @Serializable(with = ValueStringSerializer::class)
    val label: Value<String>? = null,
    @Serializable(with = ValueBoolSerializer::class)
    val visible: Value<Boolean>? = null,
    @Serializable(with = ValueBoolSerializer::class)
    val disabled: Value<Boolean>? = null,
    @Serializable(with = ValueStringSerializer::class)
    val value: Value<String>? = null,
    @Serializable(with = ValueStringSerializer::class)
    val link: Value<String>? = null,
    @Serializable(with = ValueStringSerializer::class)
    val src: Value<String>? = null,
    @Serializable(with = ValueStringSerializer::class)
    val systemImage: Value<String>? = null,
    @Serializable(with = ValueStringSerializer::class)
    val url: Value<String>? = null,
    @Serializable(with = ComponentHeaderFooterContentSerializer::class)
    val header: ComponentHeaderFooterContent? = null,
    @Serializable(with = ComponentHeaderFooterContentSerializer::class)
    val footer: ComponentHeaderFooterContent? = null,
    @Serializable(with = ValueStringSerializer::class)
    val placeholder: Value<String>? = null,
    @Serializable(with = ValueStringSerializer::class)
    val transition: Value<String>? = null,
    @Serializable(with = ValueDoubleSerializer::class)
    val columns: Value<Double>? = null,
    @Serializable(with = ValueDoubleSerializer::class)
    val minColumnWidth: Value<Double>? = null,
    @Serializable(with = ValueDoubleSerializer::class)
    val maxColumnWidth: Value<Double>? = null,
    @Serializable(with = ValueDirectionAxisSerializer::class)
    val direction: Value<DirectionAxis>? = null,
    @Serializable(with = ValueStringMapSerializer::class)
    val props: Map<String, Value<String>>? = null,

    // Script properties -- always Lua scripts, no {{ }} needed
    val items: String? = null,
    val render: String? = null,
    val onTap: String? = null,
    val onChanged: String? = null,
    val onSubmit: String? = null,
    val onHover: String? = null,

    // Always-literal properties
    val inputType: String? = null,
    var style: ComponentStyle? = null,
    val children: List<ComponentDefinition>? = null,
    val bindings: List<String>? = null,
    val localState: Map<String, StateValue>? = null,
    val background: ComponentDefinition? = null,
    val stateKey: String? = null,
    val min: Double? = null,
    val max: Double? = null,
    val step: Double? = null,
    val options: OptionsSource? = null,
    val pickerStyle: String? = null,
    val datePickerStyle: String? = null,
    val displayedComponents: String? = null,
    val formStyle: String? = null,
    val shouldGrowToFitParent: Boolean? = null,
    val contextMenu: List<ContextMenuItem>? = null,
    val lazy: Boolean? = null,
    val marks: List<MarkDefinition>? = null,
    val legendPosition: String? = null,
    val hideXAxis: Boolean? = null,
    val hideYAxis: Boolean? = null,
    val colors: List<String>? = null
)
