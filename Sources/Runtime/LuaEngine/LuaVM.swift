import Foundation
import SwiftUI
import CLua

// MARK: - Environment Key

private struct LuaVMKey: EnvironmentKey {
    static let defaultValue: LuaVM? = nil
}

extension EnvironmentValues {
    public var luaVM: LuaVM? {
        get { self[LuaVMKey.self] }
        set { self[LuaVMKey.self] = newValue }
    }
}

/// Swift-side representation of a Lua value bridged across the C API.
public enum LuaValue: Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case table([String: LuaValue])
    case array([LuaValue])
    case `nil`

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var numberValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var tableValue: [String: LuaValue]? {
        if case .table(let t) = self { return t }
        return nil
    }

}

/// Errors produced by Lua script loading, execution, or VM initialization.
public enum LuaError: Error, LocalizedError {
    case runtimeError(String)
    case syntaxError(String)
    case memoryError
    case initializationFailed

    public var errorDescription: String? {
        switch self {
        case .runtimeError(let msg): return "Lua runtime error: \(msg)"
        case .syntaxError(let msg): return "Lua syntax error: \(msg)"
        case .memoryError: return "Lua memory error"
        case .initializationFailed: return "Failed to initialize Lua VM"
        }
    }
}

/// Sandboxed Lua 5.4 virtual machine for evaluating expressions and scripts.
public final class LuaVM: @unchecked Sendable {
    private let L: OpaquePointer

    public typealias SwiftFunction = ([LuaValue]) -> LuaValue

    private var registeredFunctions: [String: SwiftFunction] = [:]
    private var retainedClosures: [UnsafeMutableRawPointer] = []

    /// Active interval timers keyed by ID
    private var timers: [Int: Timer] = [:]
    private var timerNextId = 0

    /// Callback invoked when the `state` table is modified from Lua
    public var onStateChanged: ((String, LuaValue) -> Void)?

    /// Callback invoked when the `scope` table is modified from Lua
    public var onScopeChanged: ((String, LuaValue) -> Void)?

    public init(source: String? = nil) throws {
        guard let state = luaL_newstate() else {
            throw LuaError.initializationFailed
        }
        self.L = state
        luaL_openlibs(L)
        setupStateTable()
        setupScopeTable()
        setupMelodyTable()
        setupGlobalUtilities()
        print("[Melody:VM] Initializing Lua VM from \(source ?? "Unknown source")")
    }

    deinit {
        print("[Melody:VM] deinit")
        // 1. Stop timers so no more callbacks fire
        invalidateAllTimers()
        // 2. Break Swift-side callback cycles
        onStateChanged = nil
        onScopeChanged = nil
        registeredFunctions.removeAll()
        // 3. Close Lua state FIRST — after this, no Lua code can run,
        //    so ClosureWrapper pointers in the Lua state become irrelevant
        lua_close(L)
        // 4. NOW release the ClosureWrappers (safe — Lua can't call them anymore)
        for ptr in retainedClosures {
            Unmanaged<ClosureWrapper>.fromOpaque(ptr).release()
        }
        retainedClosures.removeAll()
    }

    /// Cancel all active interval timers
    public func invalidateAllTimers() {
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
    }

    // MARK: - Script Execution

    /// Execute a Lua script string
    @discardableResult
    public func execute(_ script: String) throws -> LuaValue {
        let status = luaL_loadstring(L, script)
        if status != LUA_OK {
            let msg = String(cString: lua_tolstring(L, -1, nil))
            lua_settop(L, -(1)-1)
            throw LuaError.syntaxError(msg)
        }

        let callStatus = lua_pcallk(L, 0, 1, 0, 0, nil)
        if callStatus != LUA_OK {
            let msg = String(cString: lua_tolstring(L, -1, nil))
            lua_settop(L, -(1)-1)
            throw LuaError.runtimeError(msg)
        }

        let result = readValue(at: -1)
        lua_settop(L, -(1)-1)
        return result
    }

    /// Evaluate a Lua expression and return its value
    public func evaluate(_ expression: String) throws -> LuaValue {
        return try execute("return \(expression)")
    }

    // MARK: - State Management

    /// Set a value in the Lua `state` table (triggers onStateChanged → SwiftUI re-render)
    public func setState(key: String, value: LuaValue) {
        lua_getglobal(L, "state")
        pushValue(value)
        lua_setfield(L, -2, key)
        lua_settop(L, -(1)-1)
    }

    /// Set a value in the Lua state backing table WITHOUT triggering onStateChanged.
    /// Use for ephemeral variables (e.g., _current_item) that should not cause re-renders.
    public func setStateRaw(key: String, value: LuaValue) {
        lua_getglobal(L, "_state_data")
        pushValue(value)
        lua_setfield(L, -2, key)
        lua_settop(L, -(1)-1)
    }

    /// Get a value from the Lua `state` table
    public func getState(key: String) -> LuaValue {
        lua_getglobal(L, "state")
        lua_getfield(L, -1, key)
        let value = readValue(at: -1)
        lua_settop(L, -(2)-1)
        return value
    }

    /// Set multiple state values at once
    public func setInitialState(_ state: [String: LuaValue]) {
        for (key, value) in state {
            setState(key: key, value: value)
        }
    }

    // MARK: - Scope Management

    /// Set a value in the Lua `scope` table
    public func setScopeState(key: String, value: LuaValue) {
        lua_getglobal(L, "_scope_data")
        pushValue(value)
        lua_setfield(L, -2, key)
        lua_settop(L, -(1)-1)
    }

    /// Clear all scope data
    public func clearScope() {
        lua_createtable(L, 0, 0)
        lua_setglobal(L, "_scope_data")
    }

    /// Set a top-level Lua global variable (bypasses state table / no re-render triggered)
    public func setGlobal(_ name: String, value: LuaValue) {
        pushValue(value)
        lua_setglobal(L, name)
    }

    /// Generate a Lua `local ${X} = { ... }` prefix for self-contained evaluation.
    /// Each call site gets its own local — no global mutation, no race conditions.
    public func localPrefix(key: String, for value: [String: LuaValue]) -> String {
        var parts: [String] = []
        for (key, value) in value {
            let escapedKey = key.replacingOccurrences(of: "\"", with: "\\\"")
            parts.append("[\"\(escapedKey)\"] = \(luaLiteral(value))")
        }
        return "local \(key) = {" + parts.joined(separator: ", ") + "}\n"
    }

    /// Convert a LuaValue to its Lua source literal representation
    private func luaLiteral(_ value: LuaValue) -> String {
        switch value {
        case .string(let s):
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\0", with: "\\0")
            return "\"\(escaped)\""
        case .number(let n):
            if n == n.rounded() && n >= Double(Int64.min) && n <= Double(Int64.max) {
                return String(Int64(n))
            }
            return String(n)
        case .bool(let b):
            return b ? "true" : "false"
        case .nil:
            return "nil"
        case .table(let dict):
            let entries = dict.map { "[\"\($0.key)\"] = \(luaLiteral($0.value))" }
            return "{" + entries.joined(separator: ", ") + "}"
        case .array(let arr):
            return "{" + arr.map { luaLiteral($0) }.joined(separator: ", ") + "}"
        }
    }

    /// Set a field on any global table (e.g., params.id = "123")
    public func setGlobal(table: String, key: String, value: LuaValue) {
        lua_getglobal(L, table)
        pushValue(value)
        lua_setfield(L, -2, key)
        lua_settop(L, -(1)-1)
    }

    // MARK: - Function Registration

    /// Register a Swift function that can be called from Lua via melody.functionName
    public func registerMelodyFunction(name: String, function: @escaping SwiftFunction) {
        registeredFunctions[name] = function
        lua_getglobal(L, "melody")

        let closureWrapper = ClosureWrapper(function: function, vm: self)
        let pointer = Unmanaged.passRetained(closureWrapper).toOpaque()
        retainedClosures.append(pointer)

        lua_pushlightuserdata(L, pointer)
        lua_pushcclosure(L, melodySwiftBridge, 1)

        lua_setfield(L, -2, name)
        lua_settop(L, -(1)-1)
    }

    /// Register a Swift function under a plugin namespace (e.g., `keychain.get`).
    /// Creates the namespace table as a global if it doesn't exist yet.
    public func registerPluginFunction(namespace: String, name: String, function: @escaping SwiftFunction) {
        lua_getglobal(L, namespace)
        if lua_type(L, -1) != LUA_TTABLE {
            lua_settop(L, -(1)-1)
            lua_createtable(L, 0, 0)
            lua_setglobal(L, namespace)
            lua_getglobal(L, namespace)
        }

        let closureWrapper = ClosureWrapper(function: function, vm: self)
        let pointer = Unmanaged.passRetained(closureWrapper).toOpaque()
        retainedClosures.append(pointer)

        lua_pushlightuserdata(L, pointer)
        lua_pushcclosure(L, melodySwiftBridge, 1)

        lua_setfield(L, -2, name)
        lua_settop(L, -(1)-1)
    }

    // MARK: - Private Setup

    /// Create the global `state` table with a metatable that fires onStateChanged
    private func setupStateTable() {
        lua_createtable(L, 0, 0)
        lua_setglobal(L, "_state_data")

        lua_createtable(L, 0, 0)

        lua_createtable(L, 0, 0)

        let vmPointer = Unmanaged.passUnretained(self).toOpaque()

        lua_pushlightuserdata(L, vmPointer)
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            let key = String(cString: lua_tolstring(L, 2, nil))
            lua_getglobal(L, "_state_data")
            lua_getfield(L, -1, key)
            return 1
        }, 1)
        lua_setfield(L, -2, "__index")

        lua_pushlightuserdata(L, vmPointer)
        lua_pushcclosure(L, { S in
            guard let S = S else { return 0 }
            let vmPtr = lua_touserdata(S, clua_upvalueindex(1))!
            let vm = Unmanaged<LuaVM>.fromOpaque(vmPtr).takeUnretainedValue()

            let key = String(cString: lua_tolstring(S, 2, nil))

            lua_getglobal(S, "_state_data")
            lua_pushvalue(S, 3)
            lua_setfield(S, -2, key)
            lua_settop(S, -(1)-1)

            let value = vm.readValue(in: S, at: 3)
            vm.onStateChanged?(key, value)

            return 0
        }, 1)
        lua_setfield(L, -2, "__newindex")

        lua_setmetatable(L, -2)

        lua_setglobal(L, "state")
    }

    /// Create the global `scope` table with a metatable that fires onScopeChanged
    private func setupScopeTable() {
        lua_createtable(L, 0, 0)
        lua_setglobal(L, "_scope_data")

        lua_createtable(L, 0, 0)

        lua_createtable(L, 0, 0)

        let vmPointer = Unmanaged.passUnretained(self).toOpaque()

        lua_pushlightuserdata(L, vmPointer)
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            let key = String(cString: lua_tolstring(L, 2, nil))
            lua_getglobal(L, "_scope_data")
            lua_getfield(L, -1, key)
            return 1
        }, 1)
        lua_setfield(L, -2, "__index")

        lua_pushlightuserdata(L, vmPointer)
        lua_pushcclosure(L, { S in
            guard let S = S else { return 0 }
            let vmPtr = lua_touserdata(S, clua_upvalueindex(1))!
            let vm = Unmanaged<LuaVM>.fromOpaque(vmPtr).takeUnretainedValue()

            let key = String(cString: lua_tolstring(S, 2, nil))

            lua_getglobal(S, "_scope_data")
            lua_pushvalue(S, 3)
            lua_setfield(S, -2, key)
            lua_settop(S, -(1)-1)

            let value = vm.readValue(in: S, at: 3)
            vm.onScopeChanged?(key, value)

            return 0
        }, 1)
        lua_setfield(L, -2, "__newindex")

        lua_setmetatable(L, -2)

        lua_setglobal(L, "scope")
    }

    /// Create the global `melody` table
    private func setupMelodyTable() {
        #if os(macOS)
        lua_pushstring(L, "macos")
        lua_setglobal(L, "platform")
        lua_pushboolean(L, 1)
        lua_setglobal(L, "isDesktop")
        #else
        lua_pushstring(L, "ios")
        lua_setglobal(L, "platform")
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        lua_pushboolean(L, isIPad ? 1 : 0)
        lua_setglobal(L, "isDesktop")
        #endif

        #if DEBUG
        lua_pushboolean(L, 1)
        #else
        lua_pushboolean(L, 0)
        #endif
        lua_setglobal(L, "isDebug")

        lua_createtable(L, 0, 0)

        let vmPointer = Unmanaged.passUnretained(self).toOpaque()
        lua_pushlightuserdata(L, vmPointer)
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            if lua_type(L, 1) == LUA_TSTRING {
                let msg = String(cString: lua_tolstring(L, 1, nil))
                print("[melody.log] \(msg)")
                #if MELODY_DEV
                DevLogger.shared.log(msg, source: "lua")
                #endif
            }
            return 0
        }, 1)
        lua_setfield(L, -2, "log")

        lua_setglobal(L, "melody")

        _ = try? execute("""
            melody.fetch = function(url, options)
                return coroutine.yield("__fetch__", url, options or {})
            end
        """)

        _ = try? execute("""
            melody.fetchAll = function(requests)
                return coroutine.yield("__fetch_all__", requests)
            end
        """)

        registerMelodyFunction(name: "_startTimer") { [weak self] args in
            guard let self,
                  let timerId = args.first?.numberValue.map({ Int($0) }),
                  let intervalMs = args.dropFirst().first?.numberValue else {
                return .nil
            }
            let interval = intervalMs / 1000.0
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.executeAsync("""
                    local cb = _melody_timers[\(timerId)]
                    if cb then cb() end
                """) { _ in }
            }
            self.timers[timerId] = timer
            return .nil
        }

        registerMelodyFunction(name: "_stopTimer") { [weak self] args in
            guard let self,
                  let timerId = args.first?.numberValue.map({ Int($0) }) else {
                return .nil
            }
            self.timers[timerId]?.invalidate()
            self.timers.removeValue(forKey: timerId)
            return .nil
        }

        _ = try? execute("""
            _melody_timers = {}
            _melody_timer_id = 0

            melody.setInterval = function(callback, ms)
                _melody_timer_id = _melody_timer_id + 1
                local id = _melody_timer_id
                _melody_timers[id] = callback
                melody._startTimer(id, ms)
                return id
            end

            melody.clearInterval = function(id)
                if id then
                    _melody_timers[id] = nil
                    melody._stopTimer(id)
                end
            end
        """)
    }

    /// Register global utility functions available in all Lua scripts.
    private func setupGlobalUtilities() {
        _ = try? execute("""
            function urlEncode(str)
                if type(str) ~= "string" then return "" end
                str = string.gsub(str, "([^%w%-%.%_%~])", function(c)
                    return string.format("%%%02X", string.byte(c))
                end)
                return str
            end

            function urlDecode(str)
                if type(str) ~= "string" then return "" end
                str = string.gsub(str, "%%(%x%x)", function(h)
                    return string.char(tonumber(h, 16))
                end)
                return str
            end

            function asset(path)
                return "assets/" .. path
            end
        """)

        _ = try? execute("""
            function dump(t, indent)
                if type(t) ~= "table" then return tostring(t) end
                indent = indent or ""
                local next_indent = indent .. "  "
                local parts = {}
                local is_array = true
                local max_i = 0
                for k, _ in pairs(t) do
                    if type(k) ~= "number" then
                        is_array = false
                        break
                    end
                    if k > max_i then max_i = k end
                end
                if is_array and max_i == #t then
                    for i, v in ipairs(t) do
                        if type(v) == "table" then
                            table.insert(parts, next_indent .. dump(v, next_indent))
                        else
                            table.insert(parts, next_indent .. tostring(v))
                        end
                    end
                else
                    for k, v in pairs(t) do
                        local key = tostring(k)
                        if type(v) == "table" then
                            table.insert(parts, next_indent .. key .. " = " .. dump(v, next_indent))
                        else
                            table.insert(parts, next_indent .. key .. " = " .. tostring(v))
                        end
                    end
                end
                return "{\\n" .. table.concat(parts, ",\\n") .. "\\n" .. indent .. "}"
            end
        """)
    }

    // MARK: - Value Conversion

    /// Push a LuaValue onto the main thread's Lua stack
    func pushValue(_ value: LuaValue) {
        pushValue(value, in: L)
    }

    /// Push a LuaValue onto an explicit lua_State's stack (for coroutines)
    func pushValue(_ value: LuaValue, in S: OpaquePointer) {
        switch value {
        case .string(let s):
            let utf8 = Array(s.utf8)
            utf8.withUnsafeBytes { buf in
                _ = lua_pushlstring(S, buf.baseAddress?.assumingMemoryBound(to: CChar.self), utf8.count)
            }
        case .number(let n):
            if n == n.rounded() && n >= Double(Int64.min) && n <= Double(Int64.max) {
                lua_pushinteger(S, lua_Integer(n))
            } else {
                lua_pushnumber(S, n)
            }
        case .bool(let b):
            lua_pushboolean(S, b ? 1 : 0)
        case .table(let dict):
            lua_createtable(S, 0, Int32(dict.count))
            for (key, val) in dict {
                pushValue(val, in: S)
                lua_setfield(S, -2, key)
            }
        case .array(let arr):
            lua_createtable(S, Int32(arr.count), 0)
            for (i, val) in arr.enumerated() {
                pushValue(val, in: S)
                lua_rawseti(S, -2, lua_Integer(i + 1))
            }
        case .nil:
            lua_pushnil(S)
        }
    }

    /// Read a Lua value from the main thread's stack
    func readValue(at index: Int32) -> LuaValue {
        readValue(in: L, at: index)
    }

    /// Read a Lua value from an explicit lua_State's stack (for coroutines)
    func readValue(in S: OpaquePointer, at index: Int32) -> LuaValue {
        let type = lua_type(S, index)
        switch type {
        case LUA_TSTRING:
            var len: Int = 0
            if let ptr = lua_tolstring(S, index, &len) {
                return .string(String(decoding: UnsafeRawBufferPointer(start: ptr, count: len), as: UTF8.self))
            }
            return .string("")
        case LUA_TNUMBER:
            if lua_isinteger(S, index) != 0 {
                return .number(Double(lua_tointegerx(S, index, nil)))
            }
            return .number(lua_tonumberx(S, index, nil))
        case LUA_TBOOLEAN:
            return .bool(lua_toboolean(S, index) != 0)
        case LUA_TTABLE:
            return readTable(in: S, at: index)
        case LUA_TNIL, LUA_TNONE:
            return .nil
        default:
            return .nil
        }
    }

    /// Read a Lua table from an explicit lua_State's stack
    private func readTable(in S: OpaquePointer, at index: Int32) -> LuaValue {
        var dict: [String: LuaValue] = [:]
        var arr: [LuaValue] = []
        var isArray = true
        var maxIndex: lua_Integer = 0

        let absIndex = index > 0 ? index : lua_gettop(S) + index + 1

        lua_pushnil(S)
        while lua_next(S, absIndex) != 0 {
            if lua_type(S, -2) == LUA_TNUMBER && lua_isinteger(S, -2) != 0 {
                let i = lua_tointegerx(S, -2, nil)
                if i > maxIndex { maxIndex = i }
            } else {
                isArray = false
            }

            if lua_type(S, -2) == LUA_TSTRING {
                let key = String(cString: lua_tolstring(S, -2, nil))
                dict[key] = readValue(in: S, at: -1)
            }
            lua_settop(S, -(1)-1)
        }

        if isArray && maxIndex > 0 && dict.isEmpty {
            for i in 1...maxIndex {
                lua_rawgeti(S, absIndex, i)
                arr.append(readValue(in: S, at: -1))
                lua_settop(S, -(1)-1)
            }
            return .array(arr)
        }

        return .table(dict)
    }

    // MARK: - Event Dispatch

    /// Dispatch an event to this VM's Lua listeners.
    /// Looks up `_melody_event_listeners[name]` and calls each callback with `data`.
    /// Each callback runs in its own coroutine so it can use melody.fetch and other
    /// yielding operations without error.
    func dispatchEvent(name: String, data: LuaValue) {
        lua_getglobal(L, "_melody_event_listeners")
        guard lua_type(L, -1) == LUA_TTABLE else {
            lua_settop(L, -(1)-1)
            return
        }

        lua_getfield(L, -1, name)
        guard lua_type(L, -1) == LUA_TTABLE else {
            lua_settop(L, -(2)-1)
            return
        }

        let len = luaL_len(L, -1)
        guard len > 0 else {
            lua_settop(L, -(2)-1)
            return
        }

        let callbacksIdx = lua_gettop(L)

        for i in 1...len {
            lua_rawgeti(L, callbacksIdx, lua_Integer(i))
            guard lua_type(L, -1) == LUA_TFUNCTION else {
                lua_settop(L, -(1)-1)
                continue
            }

            guard let co = lua_newthread(L) else {
                lua_settop(L, -(1)-1)
                continue
            }
            let ref = luaL_ref(L, clua_registryindex())

            lua_xmove(L, co, 1)

            pushValue(data, in: co)

            resumeCoroutine(co, ref: ref, nargs: 1) { result in
                if case .failure(let error) = result {
                    print("[Melody] Event '\(name)' handler error: \(error.localizedDescription)")
                }
            }
        }

        lua_settop(L, -(2)-1)
    }

    // MARK: - Coroutine Execution

    /// Execute a Lua script as a coroutine that can yield for async operations
    /// (e.g., melody.fetch). The completion is called when the script finishes
    /// or if an error occurs. If the script yields for a fetch, the completion
    /// is deferred until the fetch completes and the coroutine finishes.
    public func executeAsync(_ script: String, completion: @escaping (Result<LuaValue, Error>) -> Void) {
        guard let co = lua_newthread(L) else {
            completion(.failure(LuaError.initializationFailed))
            return
        }
        let ref = luaL_ref(L, clua_registryindex())

        let loadStatus = luaL_loadstring(co, script)
        if loadStatus != LUA_OK {
            let msg = String(cString: lua_tolstring(co, -1, nil))
            luaL_unref(L, clua_registryindex(), ref)
            completion(.failure(LuaError.syntaxError(msg)))
            return
        }

        resumeCoroutine(co, ref: ref, nargs: 0, completion: completion)
    }

    /// Resume a yielded coroutine. nargs values must already be pushed onto co's stack.
    private func resumeCoroutine(_ co: OpaquePointer, ref: Int32, nargs: Int32, completion: @escaping (Result<LuaValue, Error>) -> Void) {
        var nresults: Int32 = 0
        let status = lua_resume(co, L, nargs, &nresults)

        switch status {
        case LUA_OK:
            let result = nresults > 0 ? readValue(in: co, at: -1) : .nil
            if nresults > 0 { lua_settop(co, -nresults - 1) }
            luaL_unref(L, clua_registryindex(), ref)
            completion(.success(result))

        case LUA_YIELD:
            let tag = nresults > 0 ? readValue(in: co, at: -nresults) : .nil

            if case .string("__fetch__") = tag, nresults >= 2 {
                let urlValue = readValue(in: co, at: -nresults + 1)
                let optionsValue = nresults >= 3 ? readValue(in: co, at: -nresults + 2) : .nil
                lua_settop(co, -nresults - 1)

                handleFetchYield(co: co, ref: ref, url: urlValue, options: optionsValue, completion: completion)
            } else if case .string("__fetch_all__") = tag, nresults >= 2 {
                let requestsValue = readValue(in: co, at: -nresults + 1)
                lua_settop(co, -nresults - 1)

                handleFetchAllYield(co: co, ref: ref, requests: requestsValue, completion: completion)
            } else {
                if nresults > 0 { lua_settop(co, -nresults - 1) }
                luaL_unref(L, clua_registryindex(), ref)
                completion(.success(.nil))
            }

        default:
            let msg = String(cString: lua_tolstring(co, -1, nil))
            luaL_unref(L, clua_registryindex(), ref)
            completion(.failure(LuaError.runtimeError(msg)))
        }
    }

    /// Handle a fetch yield: build a URLRequest, execute it asynchronously, resume the coroutine
    private func handleFetchYield(co: OpaquePointer, ref: Int32, url: LuaValue, options: LuaValue, completion: @escaping (Result<LuaValue, Error>) -> Void) {
        guard let urlString = url.stringValue,
              let requestURL = URL(string: urlString) else {
            pushValue(.table(["ok": .bool(false), "error": .string("Invalid URL")]), in: co)
            resumeCoroutine(co, ref: ref, nargs: 1, completion: completion)
            return
        }

        var request = URLRequest(url: requestURL)
        if let opts = options.tableValue {
            request.httpMethod = opts["method"]?.stringValue ?? "GET"
            if let headers = opts["headers"]?.tableValue {
                for (key, value) in headers {
                    if let str = value.stringValue {
                        request.setValue(str, forHTTPHeaderField: key)
                    }
                }
            }
            if let body = opts["body"], ["POST", "PUT", "PATCH"].contains(request.httpMethod) {
                switch body {
                case .string(let s):
                    request.httpBody = s.data(using: .utf8)
                case .table, .array:
                    let json = MelodyHTTP.luaValueToJSON(body)
                    request.httpBody = try? JSONSerialization.data(withJSONObject: json)
                    if request.value(forHTTPHeaderField: "Content-Type") == nil {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    }
                default:
                    break
                }
            }
        }

        nonisolated(unsafe) let co = co
        nonisolated(unsafe) let completion = completion
        MelodyURLSession.shared.session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }

                let result: LuaValue
                if let error = error {
                    var errorTable: [String: LuaValue] = [
                        "ok": .bool(false),
                        "error": .string(error.localizedDescription)
                    ]
                    if MelodyURLSession.isSSLError(error) {
                        errorTable["sslError"] = .bool(true)
                        errorTable["host"] = .string(requestURL.host ?? "")
                    }
                    result = .table(errorTable)
                } else {
                    let httpResponse = response as? HTTPURLResponse
                    let statusCode = httpResponse?.statusCode ?? 0
                    let cookies = MelodyHTTP.extractCookies(from: httpResponse)
                    let headers = MelodyHTTP.extractHeaders(from: httpResponse)
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data),
                       let luaValue = MelodyHTTP.jsonToLuaValue(json) {
                        result = .table([
                            "ok": .bool(statusCode >= 200 && statusCode < 400),
                            "status": .number(Double(statusCode)),
                            "data": luaValue,
                            "cookies": cookies,
                            "headers": headers
                        ])
                    } else {
                        let bodyString = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
                        result = .table([
                            "ok": .bool(statusCode >= 200 && statusCode < 400),
                            "status": .number(Double(statusCode)),
                            "data": .string(bodyString),
                            "cookies": cookies,
                            "headers": headers
                        ])
                    }
                }

                self.pushValue(result, in: co)
                self.resumeCoroutine(co, ref: ref, nargs: 1, completion: completion)
            }
        }.resume()
    }

    /// Handle a fetch_all yield: execute multiple requests concurrently, resume with array of results
    private func handleFetchAllYield(co: OpaquePointer, ref: Int32, requests: LuaValue, completion: @escaping (Result<LuaValue, Error>) -> Void) {
        let requestArray: [LuaValue]
        switch requests {
        case .array(let arr):
            requestArray = arr
        case .table(let dict):
            let sorted = dict.keys.compactMap { Int($0) }.sorted()
            requestArray = sorted.map { dict[String($0)] ?? .nil }
        default:
            pushValue(.table(["ok": .bool(false), "error": .string("fetchAll requires an array of requests")]), in: co)
            resumeCoroutine(co, ref: ref, nargs: 1, completion: completion)
            return
        }

        guard !requestArray.isEmpty else {
            pushValue(.array([]), in: co)
            resumeCoroutine(co, ref: ref, nargs: 1, completion: completion)
            return
        }

        var urlRequests: [(index: Int, request: URLRequest)] = []
        for (i, spec) in requestArray.enumerated() {
            guard let specTable = spec.tableValue,
                  let urlString = specTable["url"]?.stringValue,
                  let url = URL(string: urlString) else {
                continue
            }
            var request = URLRequest(url: url)
            if let opts = specTable["options"]?.tableValue {
                request.httpMethod = opts["method"]?.stringValue ?? "GET"
                if let headers = opts["headers"]?.tableValue {
                    for (key, value) in headers {
                        if let str = value.stringValue {
                            request.setValue(str, forHTTPHeaderField: key)
                        }
                    }
                }
                if let body = opts["body"], ["POST", "PUT", "PATCH"].contains(request.httpMethod) {
                    switch body {
                    case .string(let s):
                        request.httpBody = s.data(using: .utf8)
                    case .table, .array:
                        let json = MelodyHTTP.luaValueToJSON(body)
                        request.httpBody = try? JSONSerialization.data(withJSONObject: json)
                        if request.value(forHTTPHeaderField: "Content-Type") == nil {
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        }
                    default:
                        break
                    }
                }
            }
            urlRequests.append((index: i, request: request))
        }

        let box = LockedResultsBox(count: requestArray.count)
        nonisolated(unsafe) let co = co
        nonisolated(unsafe) let completion = completion

        let group = DispatchGroup()

        for item in urlRequests {
            group.enter()
            MelodyURLSession.shared.session.dataTask(with: item.request) { data, response, error in
                let result: LuaValue
                if let error = error {
                    var errorTable: [String: LuaValue] = [
                        "ok": .bool(false),
                        "error": .string(error.localizedDescription)
                    ]
                    if MelodyURLSession.isSSLError(error) {
                        errorTable["sslError"] = .bool(true)
                        errorTable["host"] = .string(item.request.url?.host ?? "")
                    }
                    result = .table(errorTable)
                } else {
                    let httpResponse = response as? HTTPURLResponse
                    let statusCode = httpResponse?.statusCode ?? 0
                    let cookies = MelodyHTTP.extractCookies(from: httpResponse)
                    let headers = MelodyHTTP.extractHeaders(from: httpResponse)
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data),
                       let luaValue = MelodyHTTP.jsonToLuaValue(json) {
                        result = .table([
                            "ok": .bool(statusCode >= 200 && statusCode < 400),
                            "status": .number(Double(statusCode)),
                            "data": luaValue,
                            "cookies": cookies,
                            "headers": headers
                        ])
                    } else {
                        let bodyString = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
                        result = .table([
                            "ok": .bool(statusCode >= 200 && statusCode < 400),
                            "status": .number(Double(statusCode)),
                            "data": .string(bodyString),
                            "cookies": cookies,
                            "headers": headers
                        ])
                    }
                }
                box.set(index: item.index, value: result)
                group.leave()
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.pushValue(.array(box.getAll()), in: co)
            self.resumeCoroutine(co, ref: ref, nargs: 1, completion: completion)
        }
    }
}

private final class LockedResultsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [LuaValue]

    init(count: Int) {
        results = Array(repeating: .table(["ok": .bool(false), "error": .string("Skipped")]), count: count)
    }

    func set(index: Int, value: LuaValue) {
        lock.withLock { results[index] = value }
    }

    func getAll() -> [LuaValue] {
        lock.withLock { results }
    }
}

private func melodySwiftBridge(_ S: OpaquePointer?) -> Int32 {
    guard let S = S else { return 0 }
    let ptr = lua_touserdata(S, clua_upvalueindex(1))!
    let wrapper = Unmanaged<ClosureWrapper>.fromOpaque(ptr).takeUnretainedValue()

    let nargs = lua_gettop(S)
    var args: [LuaValue] = []
    if nargs > 0 {
        for i in 1...nargs {
            args.append(wrapper.vm.readValue(in: S, at: i))
        }
    }

    let result = wrapper.function(args)
    wrapper.vm.pushValue(result, in: S)
    return 1
}

private final class ClosureWrapper {
    let function: LuaVM.SwiftFunction
    unowned let vm: LuaVM

    init(function: @escaping LuaVM.SwiftFunction, vm: LuaVM) {
        self.function = function
        self.vm = vm
    }
}
