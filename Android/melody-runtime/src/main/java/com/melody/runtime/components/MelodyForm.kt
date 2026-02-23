package com.melody.runtime.components

import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import com.melody.core.schema.ComponentDefinition
import com.melody.runtime.renderer.LocalIsInFormContext

@Composable
fun MelodyForm(
    definition: ComponentDefinition,
    content: @Composable () -> Unit
) {
    CompositionLocalProvider(LocalIsInFormContext provides true) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .melodyStyle(definition.style)
        ) {
            content()
        }
    }
}
