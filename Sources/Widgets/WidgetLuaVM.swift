#if canImport(WidgetKit)
import Foundation
import CLua

/// Minimal Lua 5.4 VM for running widget parameter queries and resolve scripts
/// in the widget extension process. Uses CLua directly — does NOT depend on Runtime.
///
/// Registers only:
/// - `melody.storeGet(key)` — reads from App Group UserDefaults
/// - `melody.fetch(url, opts)` — synchronous HTTP
/// - `melody.trustHost(host)` — reads trusted hosts from App Group defaults
/// - `params` table — populated from parent parameter selections
public final class WidgetLuaVM {

    private let L: OpaquePointer
    private let suiteName: String
    private let bundleId: String

    public init(suiteName: String) {
        self.suiteName = suiteName
        // Derive main app bundle ID from extension's (strip last component)
        // e.g. "gt.quintero.krill.widgets" → "gt.quintero.krill"
        let extId = Bundle.main.bundleIdentifier ?? ""
        if let range = extId.range(of: ".", options: .backwards) {
            self.bundleId = String(extId[extId.startIndex..<range.lowerBound])
        } else {
            self.bundleId = extId
        }
        L = luaL_newstate()
        luaL_openlibs(L)
        registerMelodyTable()
    }

    deinit {
        lua_close(L)
    }

    // MARK: - Public API

    /// Set the `params` table from parent parameter selections.
    public func setParams(_ params: [String: String]) {
        lua_createtable(L, 0, 0)
        for (key, value) in params {
            lua_pushstring(L, key)
            lua_pushstring(L, value)
            lua_settable(L, -3)
        }
        lua_setglobal(L, "params")
    }

    /// Execute a Lua chunk. Throws on syntax/runtime errors.
    @discardableResult
    public func execute(_ code: String) throws -> Any? {
        let status = luaL_loadstring(L, code)
        guard status == LUA_OK else {
            let msg = lua_tolstring(L, -1, nil).map { String(cString: $0) } ?? "load error"
            clua_pop(L, 1)
            throw WidgetLuaError.loadError(msg)
        }
        let callStatus = clua_pcall(L, 0, 1, 0)
        guard callStatus == LUA_OK else {
            let msg = lua_tolstring(L, -1, nil).map { String(cString: $0) } ?? "runtime error"
            clua_pop(L, 1)
            throw WidgetLuaError.runtimeError(msg)
        }
        let result = readValue(at: -1)
        clua_pop(L, 1)
        return result
    }

    /// Execute a query script that should return an array of {id, name, subtitle?} tables.
    public func runQuery(_ code: String) throws -> [WidgetEntityResult] {
        let result = try execute(code)
        guard let array = result as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
            return WidgetEntityResult(id: id, name: name, subtitle: dict["subtitle"] as? String)
        }
    }

    /// Execute a resolve script that should return a flat {string: string} table.
    public func runResolve(_ code: String) throws -> [String: String] {
        let result = try execute(code)
        guard let dict = result as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        for (key, value) in dict {
            if let s = value as? String { out[key] = s }
            else { out[key] = "\(value)" }
        }
        return out
    }

    // MARK: - Lua Bindings

    private func registerMelodyTable() {
        lua_createtable(L, 0, 0) // melody = {}

        // melody.storeGet(key)
        let storeGetCtx = Unmanaged.passUnretained(self).toOpaque()
        lua_pushlightuserdata(L, storeGetCtx)
        lua_pushcclosure(L, { L in
            guard let L else { return 0 }
            let ctx = lua_touserdata(L, clua_upvalueindex(1))!
            let vm = Unmanaged<WidgetLuaVM>.fromOpaque(ctx).takeUnretainedValue()
            guard let key = lua_tolstring(L, 1, nil).map({ String(cString: $0) }) else {
                lua_pushnil(L)
                return 1
            }
            let storeKey = "melody.store.\(vm.bundleId)-\(key)"
            let defaults = UserDefaults(suiteName: vm.suiteName) ?? .standard
            guard let data = defaults.data(forKey: storeKey),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let inner = json["v"] else {
                lua_pushnil(L)
                return 1
            }
            vm.pushValue(inner)
            return 1
        }, 1)
        lua_setfield(L, -2, "storeGet")

        // melody.fetch(url, opts)
        let fetchCtx = Unmanaged.passUnretained(self).toOpaque()
        lua_pushlightuserdata(L, fetchCtx)
        lua_pushcclosure(L, { L in
            guard let L else { return 0 }
            let ctx = lua_touserdata(L, clua_upvalueindex(1))!
            let vm = Unmanaged<WidgetLuaVM>.fromOpaque(ctx).takeUnretainedValue()
            return vm.luaFetch(L)
        }, 1)
        lua_setfield(L, -2, "fetch")

        // melody.trustHost(host) — no-op in widget context
        lua_pushcclosure(L, { _ in return 0 }, 0)
        lua_setfield(L, -2, "trustHost")

        // No-op stubs for functions called by the app prelude
        // (storeSet, storeSave, emit, on, navigate, etc.)
        for name in ["storeSet", "storeSave", "emit", "on", "navigate", "replace",
                      "goBack", "sheet", "dismiss", "alert", "copyToClipboard",
                      "setTitle", "setInterval", "clearInterval", "switchTab"] {
            lua_pushcclosure(L, { _ in return 0 }, 0)
            lua_setfield(L, -2, name)
        }

        lua_setglobal(L, "melody")

        // Initialize empty params table
        lua_createtable(L, 0, 0)
        lua_setglobal(L, "params")
    }

    private func luaFetch(_ L: OpaquePointer) -> Int32 {
        guard let urlStr = lua_tolstring(L, 1, nil).map({ String(cString: $0) }),
              let url = URL(string: urlStr) else {
            // Return { ok = false }
            lua_createtable(L, 0, 0)
            lua_pushboolean(L, 0)
            lua_setfield(L, -2, "ok")
            return 1
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        // Read headers from opts table (second argument)
        if lua_type(L, 2) == LUA_TTABLE {
            lua_getfield(L, 2, "method")
            if let method = lua_tolstring(L, -1, nil).map({ String(cString: $0) }) {
                request.httpMethod = method.uppercased()
            }
            clua_pop(L, 1)

            lua_getfield(L, 2, "headers")
            if lua_type(L, -1) == LUA_TTABLE {
                lua_pushnil(L)
                while lua_next(L, -2) != 0 {
                    if let key = lua_tolstring(L, -2, nil).map({ String(cString: $0) }),
                       let headerValue = lua_tolstring(L, -1, nil).map({ String(cString: $0) }) {
                        request.setValue(headerValue, forHTTPHeaderField: key)
                    }
                    clua_pop(L, 1) // pop value, keep key for next iteration
                }
            }
            clua_pop(L, 1)
        }

        // Synchronous fetch using semaphore (widget extension context)
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?

        let delegate = TrustAllDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        session.dataTask(with: request) { data, _, error in
            responseData = data
            responseError = error
            semaphore.signal()
        }.resume()

        semaphore.wait()

        lua_createtable(L, 0, 0) // result table

        if let error = responseError {
            lua_pushboolean(L, 0)
            lua_setfield(L, -2, "ok")
            lua_pushstring(L, error.localizedDescription)
            lua_setfield(L, -2, "error")
        } else if let data = responseData,
                  let json = try? JSONSerialization.jsonObject(with: data) {
            lua_pushboolean(L, 1)
            lua_setfield(L, -2, "ok")
            pushValue(json)
            lua_setfield(L, -2, "data")
        } else {
            lua_pushboolean(L, 0)
            lua_setfield(L, -2, "ok")
        }

        return 1
    }

    // MARK: - Value Conversion

    /// Push a Swift value onto the Lua stack.
    func pushValue(_ value: Any) {
        switch value {
        case let s as String:
            lua_pushstring(L, s)
        case let n as NSNumber:
            if CFBooleanGetTypeID() == CFGetTypeID(n) {
                lua_pushboolean(L, n.boolValue ? 1 : 0)
            } else {
                lua_pushnumber(L, n.doubleValue)
            }
        case let arr as [Any]:
            lua_createtable(L, 0, 0)
            for (i, item) in arr.enumerated() {
                lua_pushinteger(L, lua_Integer(i + 1))
                pushValue(item)
                lua_settable(L, -3)
            }
        case let dict as [String: Any]:
            lua_createtable(L, 0, 0)
            for (key, v) in dict {
                lua_pushstring(L, key)
                pushValue(v)
                lua_settable(L, -3)
            }
        case is NSNull:
            lua_pushnil(L)
        default:
            lua_pushstring(L, "\(value)")
        }
    }

    /// Read a Lua value from the stack at the given index.
    func readValue(at index: Int32) -> Any? {
        let absIndex = index > 0 ? index : lua_gettop(L) + index + 1
        let type = lua_type(L, absIndex)
        switch type {
        case LUA_TNIL:
            return nil
        case LUA_TBOOLEAN:
            return lua_toboolean(L, absIndex) != 0
        case LUA_TNUMBER:
            let n = lua_tonumberx(L, absIndex, nil)
            if n == Double(Int64(n)) { return Int(n) }
            return n
        case LUA_TSTRING:
            return lua_tolstring(L, absIndex, nil).map { String(cString: $0) }
        case LUA_TTABLE:
            return readTable(at: absIndex)
        default:
            return nil
        }
    }

    private func readTable(at index: Int32) -> Any {
        // Determine if array or dictionary
        var isArray = true
        var maxIndex: lua_Integer = 0

        lua_pushnil(L)
        while lua_next(L, index) != 0 {
            if lua_type(L, -2) == LUA_TNUMBER {
                let k = lua_tointegerx(L, -2, nil)
                if k > maxIndex { maxIndex = k }
            } else {
                isArray = false
            }
            clua_pop(L, 1)
        }

        if isArray && maxIndex > 0 {
            var arr: [Any] = []
            for i in 1...maxIndex {
                lua_pushinteger(L, i)
                lua_gettable(L, index)
                arr.append(readValue(at: -1) ?? NSNull())
                clua_pop(L, 1)
            }
            return arr
        }

        var dict: [String: Any] = [:]
        lua_pushnil(L)
        while lua_next(L, index) != 0 {
            if let key = lua_tolstring(L, -2, nil).map({ String(cString: $0) }) {
                dict[key] = readValue(at: -1) ?? NSNull()
            }
            clua_pop(L, 1)
        }
        return dict
    }
}

// MARK: - Supporting Types

public struct WidgetEntityResult: Sendable {
    public let id: String
    public let name: String
    public let subtitle: String?

    public init(id: String, name: String, subtitle: String? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
    }
}

public enum WidgetLuaError: Error, LocalizedError {
    case loadError(String)
    case runtimeError(String)

    public var errorDescription: String? {
        switch self {
        case .loadError(let msg): return "Lua load error: \(msg)"
        case .runtimeError(let msg): return "Lua runtime error: \(msg)"
        }
    }
}

/// URLSession delegate that trusts all certificates (for self-signed Portainer servers).
private final class TrustAllDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
#endif
