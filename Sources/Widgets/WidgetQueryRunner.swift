#if canImport(WidgetKit)
import Foundation
import Core

/// High-level runner for widget parameter queries and resolve scripts.
/// Creates a `WidgetLuaVM`, loads the app lua prelude for helper functions
/// (e.g. `getServers()`), and runs the Lua query/resolve code.
public struct WidgetQueryRunner {

    private let suiteName: String
    private let appLuaPrelude: String?

    public init(suiteName: String, appLuaPrelude: String? = nil) {
        self.suiteName = suiteName
        self.appLuaPrelude = appLuaPrelude
    }

    /// Run a parameter query script with the given parent parameter values.
    /// Returns an array of entity results for the picker.
    public func runQuery(_ queryLua: String, params: [String: String] = [:]) -> [WidgetEntityResult] {
        let vm = WidgetLuaVM(suiteName: suiteName)
        vm.setParams(params)
        loadPrelude(vm)
        return (try? vm.runQuery(queryLua)) ?? []
    }

    /// Run the resolve script with all parameter selections.
    /// Returns the flat data map to save as widget config.
    public func runResolve(_ resolveLua: String, params: [String: String]) -> [String: String] {
        let vm = WidgetLuaVM(suiteName: suiteName)
        vm.setParams(params)
        loadPrelude(vm)
        return (try? vm.runResolve(resolveLua)) ?? [:]
    }

    private func loadPrelude(_ vm: WidgetLuaVM) {
        if let prelude = appLuaPrelude {
            try? vm.execute(prelude)
        }
    }
}
#endif
