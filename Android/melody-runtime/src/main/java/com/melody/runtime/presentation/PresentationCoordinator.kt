package com.melody.runtime.presentation

import androidx.compose.runtime.mutableStateOf

data class MelodyAlertButton(
    val title: String,
    val style: String? = null,
    val onTap: String? = null
)

data class MelodyAlertConfig(
    val title: String,
    val message: String? = null,
    val buttons: List<MelodyAlertButton>
)

data class MelodySheetConfig(
    val screenPath: String,
    val detent: String? = null,
    val style: String? = null,
    val showsToolbar: Boolean? = true
)

/**
 * Manages alerts and sheets presentation state.
 * Port of iOS PresentationCoordinator.swift.
 */
class PresentationCoordinator {
    var alert = mutableStateOf<MelodyAlertConfig?>(null)
    var sheet = mutableStateOf<MelodySheetConfig?>(null)
}
