/// Contract for host-app plugins that register native functions into Lua under a namespace.
public protocol MelodyPlugin {
    /// The Lua namespace for this plugin (e.g., "keychain").
    /// Used as the global table name in Lua.
    var name: String { get }

    /// Called once per LuaVM to register plugin functions.
    func register(vm: LuaVM)
}
