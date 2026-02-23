package com.melody.runtime.state

import com.melody.runtime.engine.LuaVM
import com.melody.runtime.engine.LuaValue
import java.lang.ref.WeakReference

/**
 * Cross-screen pub/sub event bus.
 * Each screen's LuaVM registers itself; emit broadcasts to all registered VMs.
 * Port of iOS MelodyEventBus.swift.
 */
class MelodyEventBus {
    private val vms = mutableMapOf<Int, WeakReference<LuaVM>>()
    private var nextId = 0
    private val observers = mutableMapOf<Int, Pair<String, (LuaValue) -> Unit>>()
    private var nextObserverId = 0

    /** Register a VM to receive events */
    fun register(vm: LuaVM): Int {
        val id = nextId++
        vms[id] = WeakReference(vm)
        return id
    }

    /** Unregister a VM */
    fun unregister(id: Int) {
        vms.remove(id)
    }

    /** Register a Kotlin-level observer for a specific event. Returns an ID for removal. */
    fun observe(event: String, handler: (LuaValue) -> Unit): Int {
        val id = nextObserverId++
        observers[id] = Pair(event, handler)
        return id
    }

    /** Remove a Kotlin-level observer by ID. */
    fun removeObserver(id: Int) {
        observers.remove(id)
    }

    /** Broadcast an event to all registered VMs and Kotlin observers */
    fun emit(event: String, data: LuaValue) {
        val stale = mutableListOf<Int>()
        for ((id, ref) in vms) {
            val vm = ref.get()
            if (vm != null) {
                vm.dispatchEvent(event, data)
            } else {
                stale.add(id)
            }
        }
        for (id in stale) {
            vms.remove(id)
        }

        for ((_, entry) in observers) {
            if (entry.first == event) {
                entry.second(data)
            }
        }
    }
}
