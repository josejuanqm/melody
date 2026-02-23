package com.melody.runtime.state

import androidx.compose.runtime.MutableIntState
import androidx.compose.runtime.mutableIntStateOf
import com.melody.runtime.engine.LuaVM
import com.melody.runtime.networking.MelodyWebSocket
import com.melody.runtime.presentation.PresentationCoordinator

/**
 * Cached entry for a single screen's VM and associated resources.
 */
class ScreenVMEntry(
    val luaVM: LuaVM,
    val screenState: ScreenState,
    val webSockets: MutableMap<Int, MelodyWebSocket>,
    val nextWsId: MutableIntState,
    val eventBusId: Int,
    val presentation: PresentationCoordinator
)

/**
 * App-level store that keeps LuaVM instances alive across navigation.
 * Keyed by actual path (e.g., "/chat/abc123"), not the route pattern.
 */
class ScreenVMStore {
    private val entries = mutableMapOf<String, ScreenVMEntry>()

    /** Incremented on clear() so ScreenView can detect store resets and re-create VMs. */
    val generation = mutableIntStateOf(0)

    fun getOrNull(path: String): ScreenVMEntry? = entries[path]

    fun put(path: String, entry: ScreenVMEntry) {
        entries[path] = entry
    }

    fun remove(path: String, eventBus: MelodyEventBus) {
        val entry = entries.remove(path) ?: return
        cleanupEntry(entry, eventBus)
    }

    fun removeAll(paths: Collection<String>, eventBus: MelodyEventBus) {
        for (path in paths) {
            remove(path, eventBus)
        }
    }

    fun clear(eventBus: MelodyEventBus) {
        for (entry in entries.values) {
            cleanupEntry(entry, eventBus)
        }
        entries.clear()
        generation.intValue++
    }

    private fun cleanupEntry(entry: ScreenVMEntry, eventBus: MelodyEventBus) {
        for (ws in entry.webSockets.values) {
            ws.disconnect()
        }
        entry.webSockets.clear()
        if (entry.eventBusId >= 0) {
            eventBus.unregister(entry.eventBusId)
        }
        entry.luaVM.close()
    }
}
