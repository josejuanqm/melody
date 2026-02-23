@file:OptIn(ExperimentalMaterial3Api::class)

package com.melody.runtime.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.OptionDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalScreenState

@Composable
fun MelodyPicker(
    definition: ComponentDefinition,
    resolvedOptions: List<OptionDefinition>,
    onChanged: (() -> Unit)? = null
) {
    val screenState = LocalScreenState.current
    val isDisabled = LocalIsDisabled.current
    val stateKey = definition.stateKey
    val label = definition.label.resolved ?: ""
    val pickerStyle = definition.pickerStyle?.lowercase() ?: "menu"

    val selectedValue = if (stateKey != null) {
        screenState.slot(stateKey).value.stringValue ?: ""
    } else {
        ""
    }

    when (pickerStyle) {
        "segmented" -> SegmentedPicker(
            options = resolvedOptions,
            selectedValue = selectedValue,
            enabled = !isDisabled,
            onSelect = { value ->
                if (stateKey != null) {
                    screenState.set(stateKey, LuaValue.StringVal(value))
                }
                onChanged?.invoke()
            },
            modifier = Modifier.melodyStyle(definition.style)
        )
        else -> DropdownPicker(
            label = label,
            options = resolvedOptions,
            selectedValue = selectedValue,
            enabled = !isDisabled,
            onSelect = { value ->
                if (stateKey != null) {
                    screenState.set(stateKey, LuaValue.StringVal(value))
                }
                onChanged?.invoke()
            },
            modifier = Modifier.melodyStyle(definition.style)
        )
    }
}

@Composable
private fun SegmentedPicker(
    options: List<OptionDefinition>,
    selectedValue: String,
    enabled: Boolean = true,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val selectedIndex = options.indexOfFirst { it.value == selectedValue }.coerceAtLeast(0)

    SingleChoiceSegmentedButtonRow(modifier = modifier) {
        options.forEachIndexed { index, option ->
            SegmentedButton(
                selected = index == selectedIndex,
                onClick = { onSelect(option.value) },
                enabled = enabled,
                shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size)
            ) {
                Text(option.label)
            }
        }
    }
}

@Composable
private fun DropdownPicker(
    label: String,
    options: List<OptionDefinition>,
    selectedValue: String,
    enabled: Boolean = true,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel = options.find { it.value == selectedValue }?.label ?: label

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { if (enabled) expanded = it },
        modifier = modifier
    ) {
        OutlinedTextField(
            value = selectedLabel,
            onValueChange = {},
            readOnly = true,
            enabled = enabled,
            label = if (label.isNotEmpty()) {{ Text(label) }} else null,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier.menuAnchor()
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.label) },
                    onClick = {
                        onSelect(option.value)
                        expanded = false
                    }
                )
            }
        }
    }
}
