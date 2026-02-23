package com.melody.runtime.plugin

import com.melody.runtime.engine.LuaVM

/** Holds all registered plugins and applies them to a LuaVM. */
class MelodyPluginRegistry(
    private val plugins: List<MelodyPlugin> = emptyList()
) {
    /** Register all plugin functions on the given VM. */
    fun register(vm: LuaVM) {
        for (plugin in plugins) {
            plugin.register(vm)
        }
    }
}
