package com.melody.runtime.components

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun MelodySpacer() {
    Spacer(modifier = Modifier.defaultMinSize(minWidth = 0.dp, minHeight = 0.dp))
}
