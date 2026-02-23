import Foundation

// MARK: - Shared VM Setup

extension LuaVM {

    /// Registers store, event, theme, and plugin functions that every Melody VM needs.
    func registerCoreFunctions(
        store: MelodyStore,
        eventBus: MelodyEventBus,
        themeColors: [String: String] = [:],
        pluginRegistry: MelodyPluginRegistry? = nil,
        appLuaPrelude: String? = nil
    ) throws {
        // MARK: Store
        registerMelodyFunction(name: "storeSet") { args in
            guard args.count >= 2, let key = args[0].stringValue else { return .nil }
            store.set(key: key, value: args[1])
            return .nil
        }
        registerMelodyFunction(name: "storeSave") { args in
            guard args.count >= 2, let key = args[0].stringValue else { return .nil }
            store.save(key: key, value: args[1])
            return .nil
        }
        registerMelodyFunction(name: "storeGet") { args in
            guard let key = args.first?.stringValue else { return .nil }
            return store.get(key: key)
        }

        // MARK: Events
        eventBus.register(vm: self)
        _ = try execute("""
            _melody_event_listeners = {}
            function melody.on(event, callback)
                if not _melody_event_listeners[event] then
                    _melody_event_listeners[event] = {}
                end
                table.insert(_melody_event_listeners[event], callback)
            end
            function melody.off(event, callback)
                if callback == nil then
                    _melody_event_listeners[event] = nil
                elseif _melody_event_listeners[event] then
                    for i, cb in ipairs(_melody_event_listeners[event]) do
                        if cb == callback then
                            table.remove(_melody_event_listeners[event], i)
                            break
                        end
                    end
                end
            end
        """)
        registerMelodyFunction(name: "emit") { args in
            if let event = args.first?.stringValue {
                let data = args.count > 1 ? args[1] : .nil
                eventBus.emit(event: event, data: data)
            }
            return .nil
        }

        // MARK: Theme
        if !themeColors.isEmpty {
            let entries = themeColors.map { key, value in
                "\(key) = \"\(value)\""
            }.joined(separator: ", ")
            try execute("theme = { \(entries) }")
        }

        // MARK: Plugins
        pluginRegistry?.register(on: self)

        // MARK: Lua Prelude
        if let prelude = appLuaPrelude {
            try execute(prelude)
        }
    }
}
