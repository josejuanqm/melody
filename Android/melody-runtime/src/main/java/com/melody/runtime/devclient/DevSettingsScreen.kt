package com.melody.runtime.devclient

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DevSettingsScreen(
    settings: DevSettings,
    logger: DevLogger = DevLogger,
    hotReload: HotReloadClient,
    onReconnect: () -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var showLogs by remember { mutableStateOf(false) }

    if (showLogs) {
        DevLogScreen(
            logger = logger,
            onBack = { showLogs = false }
        )
        return
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            Text(
                "Dev Settings",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Hot Reload section
            Text(
                "Hot Reload",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Enabled")
                Switch(
                    checked = settings.hotReloadEnabled,
                    onCheckedChange = { settings.updateHotReloadEnabled(it) }
                )
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(vertical = 4.dp)
            ) {
                Text("Status: ")
                val statusColor = if (hotReload.isConnected) Color(0xFF4CAF50) else Color(0xFFF44336)
                Text(
                    if (hotReload.isConnected) "Connected" else "Disconnected",
                    color = statusColor
                )
            }

            var hostText by remember { mutableStateOf(settings.devServerHost) }
            OutlinedTextField(
                value = hostText,
                onValueChange = {
                    hostText = it
                    settings.updateDevServerHost(it)
                },
                label = { Text("Host") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(8.dp))

            var portText by remember { mutableStateOf(settings.devServerPort.toString()) }
            OutlinedTextField(
                value = portText,
                onValueChange = { value ->
                    portText = value
                    value.toIntOrNull()?.let { settings.updateDevServerPort(it) }
                },
                label = { Text("Port") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(8.dp))

            Button(
                onClick = onReconnect,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Reconnect")
            }

            Spacer(modifier = Modifier.height(16.dp))
            HorizontalDivider()
            Spacer(modifier = Modifier.height(16.dp))

            // Logs nav row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showLogs = true }
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Logs")
                Text(
                    "${logger.entries.size}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

// MARK: - Dedicated Log Viewer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DevLogScreen(
    logger: DevLogger = DevLogger,
    onBack: () -> Unit
) {
    val timeFormat = remember { SimpleDateFormat("HH:mm:ss", Locale.getDefault()) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Logs") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    TextButton(
                        onClick = { logger.clear() },
                        enabled = logger.entries.isNotEmpty()
                    ) {
                        Text("Clear")
                    }
                }
            )
        }
    ) { padding ->
        if (logger.entries.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Text("No Logs", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 16.dp)
            ) {
                items(logger.entries.reversed(), key = { it.id }) { entry ->
                    Row(
                        modifier = Modifier.padding(vertical = 2.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            timeFormat.format(entry.timestamp),
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            "[${entry.source}]",
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace,
                            color = when (entry.source) {
                                "lua" -> Color(0xFF2196F3)
                                "hotreload" -> Color(0xFFFF9800)
                                else -> MaterialTheme.colorScheme.onSurfaceVariant
                            }
                        )
                        Text(
                            entry.message,
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace
                        )
                    }
                }
            }
        }
    }
}
