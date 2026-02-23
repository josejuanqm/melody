import Foundation

/// Stateless HTTP client that converts between ``LuaValue`` and URLSession request/responses.
public struct MelodyHTTP {
    public init() {}

    /// Perform an HTTP request and return the result as a LuaValue-compatible dictionary
    public func fetch(url: String, options: [String: LuaValue] = [:]) async throws -> LuaValue {
        guard let requestURL = URL(string: url) else {
            return .table([
                "ok": .bool(false),
                "status": .number(0),
                "error": .string("Invalid URL: \(url)")
            ])
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = options["method"]?.stringValue ?? "GET"

        if let headers = options["headers"]?.tableValue {
            for (key, value) in headers {
                if let str = value.stringValue {
                    request.setValue(str, forHTTPHeaderField: key)
                }
            }
        }

        if let body = options["body"], ["POST", "PUT", "PATCH"].contains(request.httpMethod) {
            switch body {
            case .string(let s):
                request.httpBody = s.data(using: .utf8)
            case .table, .array:
                let json = Self.luaValueToJSON(body)
                request.httpBody = try? JSONSerialization.data(withJSONObject: json)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            default:
                break
            }
        } else {
            request.httpBody = nil
        }

        do {
            let (data, response) = try await MelodyURLSession.shared.session.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let cookies = Self.extractCookies(from: httpResponse)
            let headers = Self.extractHeaders(from: httpResponse)

            if let json = try? JSONSerialization.jsonObject(with: data),
               let luaValue = Self.jsonToLuaValue(json) {
                return .table([
                    "ok": .bool((statusCode >= 200 && statusCode < 300) || statusCode == 304),
                    "status": .number(Double(statusCode)),
                    "data": luaValue,
                    "cookies": cookies,
                    "headers": headers
                ])
            }

            let bodyString = String(data: data, encoding: .utf8) ?? ""
            return .table([
                "ok": .bool((statusCode >= 200 && statusCode < 300) || statusCode == 304),
                "status": .number(Double(statusCode)),
                "data": .string(bodyString),
                "cookies": cookies,
                "headers": headers
            ])
        } catch {
            var errorTable: [String: LuaValue] = [
                "ok": .bool(false),
                "status": .number(0),
                "error": .string(error.localizedDescription)
            ]
            if MelodyURLSession.isSSLError(error) {
                errorTable["sslError"] = .bool(true)
                errorTable["host"] = .string(requestURL.host ?? "")
            }
            return .table(errorTable)
        }
    }

    /// Extract response headers as a LuaValue table (name → value)
    public static func extractHeaders(from response: HTTPURLResponse?) -> LuaValue {
        guard let response = response else { return .table([:]) }
        var table: [String: LuaValue] = [:]
        for (key, value) in response.allHeaderFields {
            table["\(key)"] = .string("\(value)")
        }
        return .table(table)
    }

    /// Extract cookies from an HTTP response as a LuaValue table (name → value)
    public static func extractCookies(from response: HTTPURLResponse?) -> LuaValue {
        guard let response = response,
              let url = response.url,
              let headerFields = response.allHeaderFields as? [String: String] else {
            return .table([:])
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        var table: [String: LuaValue] = [:]
        for cookie in cookies {
            table[cookie.name] = .string(cookie.value)
        }
        return .table(table)
    }

    /// Convert a LuaValue to a JSON-compatible object
    public static func luaValueToJSON(_ value: LuaValue) -> Any {
        switch value {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .table(let dict):
            var result: [String: Any] = [:]
            for (k, v) in dict {
                result[k] = luaValueToJSON(v)
            }
            return result
        case .array(let arr):
            return arr.map { luaValueToJSON($0) }
        case .nil:
            return NSNull()
        }
    }

    /// Convert a JSON object to LuaValue
    public static func jsonToLuaValue(_ json: Any) -> LuaValue? {
        switch json {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return .bool(number.boolValue)
            }
            return .number(number.doubleValue)
        case let array as [Any]:
            return .array(array.compactMap { jsonToLuaValue($0) })
        case let dict as [String: Any]:
            var table: [String: LuaValue] = [:]
            for (key, value) in dict {
                table[key] = jsonToLuaValue(value) ?? .nil
            }
            return .table(table)
        case is NSNull:
            return .nil
        default:
            return nil
        }
    }
}
