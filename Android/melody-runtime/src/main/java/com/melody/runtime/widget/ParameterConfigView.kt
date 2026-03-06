package com.melody.runtime.widget

import WidgetParameterDefinition
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

/**
 * Native Compose UI for parameter-based widget configuration.
 * Renders a dropdown picker for each parameter, with dependent parameters
 * re-querying when their parent selection changes.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ParameterConfigView(
    title: String,
    parameters: List<WidgetParameterDefinition>,
    resolveLua: String?,
    appLuaPrelude: String?,
    onDone: (Map<String, String>) -> Unit,
    onCancel: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // State for each parameter's options and selection
    val optionsMap = remember { mutableStateMapOf<String, List<EntityOption>>() }
    val selectionMap = remember { mutableStateMapOf<String, EntityOption?>() }
    val loadingMap = remember { mutableStateMapOf<String, Boolean>() }

    val runner = remember { WidgetQueryRunner(context, appLuaPrelude) }

    // Load root parameters on mount
    LaunchedEffect(Unit) {
        for (param in parameters) {
            if (param.dependsOn.isNullOrEmpty()) {
                loadingMap[param.id] = true
                val results = runner.runQuery(param.query)
                optionsMap[param.id] = results
                loadingMap[param.id] = false
            }
        }
    }

    // Re-load dependent parameters when parent selection changes
    for (param in parameters) {
        val deps = param.dependsOn
        if (!deps.isNullOrEmpty()) {
            val parentValues = deps.map { depId -> selectionMap[depId]?.id }
            LaunchedEffect(parentValues) {
                // Only load if all parents are selected
                if (parentValues.all { it != null }) {
                    loadingMap[param.id] = true
                    // Clear current selection and downstream
                    selectionMap[param.id] = null
                    clearDownstream(param.id, parameters, selectionMap, optionsMap)

                    val parentParams = deps.associate { depId ->
                        depId to (selectionMap[depId]?.id ?: "")
                    }
                    val results = runner.runQuery(param.query, parentParams)
                    optionsMap[param.id] = results
                    loadingMap[param.id] = false
                } else {
                    optionsMap[param.id] = emptyList()
                    selectionMap[param.id] = null
                }
            }
        }
    }

    val allSelected = parameters.all { selectionMap[it.id] != null }

    val isDark = androidx.compose.foundation.isSystemInDarkTheme()
    val colorScheme = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
        if (isDark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
    } else {
        if (isDark) darkColorScheme() else lightColorScheme()
    }

    MaterialTheme(colorScheme = colorScheme) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(title) },
                    navigationIcon = {
                        TextButton(onClick = onCancel) {
                            Text("Cancel")
                        }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .padding(padding)
                    .padding(horizontal = 16.dp)
                    .fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                for (param in parameters) {
                    val options = optionsMap[param.id] ?: emptyList()
                    val selected = selectionMap[param.id]
                    val isLoading = loadingMap[param.id] == true
                    val paramDeps = param.dependsOn
                    val isEnabled = paramDeps.isNullOrEmpty() ||
                        paramDeps.all { selectionMap[it] != null }

                    ParameterPicker(
                        title = param.title,
                        options = options,
                        selected = selected,
                        isLoading = isLoading,
                        isEnabled = isEnabled,
                        onSelect = { option ->
                            selectionMap[param.id] = option
                        }
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                Button(
                    onClick = {
                        scope.launch {
                            val selectedParams = parameters.associate { param ->
                                param.id to (selectionMap[param.id]?.id ?: "")
                            }
                            val data = if (resolveLua != null) {
                                runner.runResolve(resolveLua, selectedParams)
                            } else {
                                selectedParams
                            }
                            onDone(data)
                        }
                    },
                    enabled = allSelected,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp)
                        .height(50.dp)
                ) {
                    Text("Done")
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ParameterPicker(
    title: String,
    options: List<EntityOption>,
    selected: EntityOption?,
    isLoading: Boolean,
    isEnabled: Boolean,
    onSelect: (EntityOption) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.padding(bottom = 4.dp)
        )

        if (isLoading) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        } else {
            ExposedDropdownMenuBox(
                expanded = expanded,
                onExpandedChange = { if (isEnabled && options.isNotEmpty()) expanded = it }
            ) {
                OutlinedTextField(
                    value = selected?.name ?: if (isEnabled) "Select..." else "Select ${title.lowercase()} first",
                    onValueChange = {},
                    readOnly = true,
                    enabled = isEnabled,
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                    modifier = Modifier
                        .menuAnchor()
                        .fillMaxWidth(),
                    supportingText = selected?.subtitle?.let { { Text(it) } }
                )

                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    for (option in options) {
                        DropdownMenuItem(
                            text = {
                                Column {
                                    Text(option.name)
                                    option.subtitle?.let {
                                        Text(
                                            it,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            },
                            onClick = {
                                onSelect(option)
                                expanded = false
                            }
                        )
                    }
                }
            }
        }
    }
}

private fun clearDownstream(
    parentId: String,
    parameters: List<WidgetParameterDefinition>,
    selectionMap: MutableMap<String, EntityOption?>,
    optionsMap: MutableMap<String, List<EntityOption>>
) {
    for (param in parameters) {
        if (param.dependsOn?.contains(parentId) == true) {
            selectionMap[param.id] = null
            optionsMap[param.id] = emptyList()
            clearDownstream(param.id, parameters, selectionMap, optionsMap)
        }
    }
}
