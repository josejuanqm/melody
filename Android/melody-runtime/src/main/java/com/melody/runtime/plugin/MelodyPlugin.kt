package com.melody.runtime.plugin

import com.melody.runtime.engine.LuaVM

/**
 * Interface for Melody plugins that register native Lua functions.
 *
 * Each plugin exposes functions under its own top-level Lua namespace.
 * For example, a "keychain" plugin registers `keychain.get()`, `keychain.set()`, etc.
 */
interface MelodyPlugin {
    /** The Lua namespace for this plugin (e.g., "keychain"). */
    val name: String

    /** Called once per LuaVM to register plugin functions. */
    fun register(vm: LuaVM)
}
