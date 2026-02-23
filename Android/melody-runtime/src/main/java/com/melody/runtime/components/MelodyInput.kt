package com.melody.runtime.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.TextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.*
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.renderer.LocalIsDisabled
import com.melody.runtime.renderer.LocalIsInFormContext
import com.melody.runtime.renderer.LocalScreenState

@Composable
fun MelodyInput(
    definition: ComponentDefinition,
    resolvedLabel: String,
    resolvedValue: String,
    onChanged: (String) -> Unit,
    onSubmit: (() -> Unit)? = null
) {
    val screenState = LocalScreenState.current
    val isDisabled = LocalIsDisabled.current
    val stateKey = definition.stateKey
    var text by remember { mutableStateOf(resolvedValue) }

    if (stateKey != null) {
        val stateValue = screenState.slot(stateKey).value
        val stateString = stateValue.stringValue ?: ""
        LaunchedEffect(stateString) {
            if (text != stateString) text = stateString
        }
    }

    val inputType = definition.inputType?.lowercase() ?: "text"
    val isSecure = inputType == "password" || inputType == "secure"
    val isTextarea = inputType == "textarea"

    val keyboardType = when (inputType) {
        "url" -> KeyboardType.Uri
        "email" -> KeyboardType.Email
        "number" -> KeyboardType.Number
        "phone" -> KeyboardType.Phone
        else -> KeyboardType.Text
    }

    val capitalization = when (inputType) {
        "url", "email" -> KeyboardCapitalization.None
        else -> KeyboardCapitalization.Sentences
    }

    val visualTransformation = if (isSecure) {
        PasswordVisualTransformation()
    } else {
        VisualTransformation.None
    }

    var imeAction = when {
        isTextarea -> ImeAction.Default
        onSubmit != null && inputType == "search" -> ImeAction.Search
        onSubmit != null -> ImeAction.Done
        else -> ImeAction.Next
    }

    val minHeight = definition.style?.minHeight.resolved?.dp ?: if (isTextarea) 120.dp else 0.dp
    val heightModifier = if (isTextarea) {
        Modifier.fillMaxWidth().heightIn(min = minHeight)
    } else {
        Modifier.fillMaxWidth()
    }

    val focusManager = LocalFocusManager.current

    TextField(
        value = text,
        onValueChange = { newValue ->
            text = newValue
            if (stateKey != null) {
                screenState.set(stateKey, com.melody.runtime.engine.LuaValue.StringVal(newValue))
            }
            onChanged(newValue)
        },
        label = if (resolvedLabel.isNotEmpty()) {{ Text(resolvedLabel) }} else null,
        placeholder = definition.placeholder.resolved?.let {{ Text(it) }},
        visualTransformation = visualTransformation,
        keyboardOptions = KeyboardOptions(
            keyboardType = keyboardType,
            capitalization = capitalization,
            autoCorrectEnabled = inputType != "url" && inputType != "email" && !isSecure,
            imeAction = imeAction
        ),
        keyboardActions = KeyboardActions(
            onDone = onSubmit?.let { cb -> { cb() } },
            onSearch = onSubmit?.let { cb -> { cb() } },
            onNext = { focusManager.moveFocus(FocusDirection.Next) }
        ),
        enabled = !isDisabled,
        singleLine = !isTextarea,
        modifier = heightModifier.melodyStyle(definition.style, skipPadding = true)
    )
}
