package com.melody.runtime.renderer

import androidx.compose.runtime.*
import com.melody.core.schema.ComponentDefinition
import com.melody.runtime.state.LocalState

/**
 * Creates a local state scope for child components.
 * Port of iOS StateProviderView.swift.
 */
@Composable
fun StateProviderView(definition: ComponentDefinition) {
    val localState = remember { LocalState() }

    LaunchedEffect(definition) {
        localState.initialize(definition.localState)
    }

    CompositionLocalProvider(
        LocalLocalState provides localState
    ) {
        definition.children?.let { ComponentRenderer(components = it) }
    }
}
