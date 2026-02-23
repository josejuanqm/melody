import SwiftUI
import Core

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Screen Setup

extension ScreenView {

    var vmKey: String {
        actualPath ?? definition.path
    }

    func setupScreen() {
        do {
            let anchor = vmAnchor ?? VMLifecycleAnchor(key: vmKey, registry: vmRegistry)
            if vmAnchor == nil { vmAnchor = anchor }

            let (vm, isNew) = try vmRegistry.acquire(for: vmKey, anchorId: anchor.id, source: definition.title)
            self.luaVM = vm

            if isNew {
                screenState.initialize(from: definition.state)

                for (key, value) in screenState.allValues {
                    vm.setState(key: key, value: value)
                }

                registerNavigationFunctions(vm: vm)
                registerPresentationFunctions(vm: vm)
                registerUtilityFunctions(vm: vm)
                registerWebSocketFunctions(vm: vm)

                try vm.registerCoreFunctions(
                    store: store,
                    eventBus: eventBus,
                    themeColors: themeColors,
                    pluginRegistry: pluginRegistry,
                    appLuaPrelude: appLuaPrelude
                )

                try vm.execute("params = {}")
                if let actual = actualPath {
                    let routeParams = navigator.extractParams(from: actual, route: definition.path)
                    for (key, value) in routeParams {
                        vm.setGlobal(table: "params", key: key, value: .string(value))
                    }
                    if let navProps = navigator.navigationProps.removeValue(forKey: actual) {
                        for (key, value) in navProps {
                            vm.setGlobal(table: "params", key: key, value: value)
                        }
                    }
                }

                let isInSheet = melodyDismiss != nil
                try vm.execute("context = { isSheet = \(isInSheet) }")
            } else {
                if let stateKeys = definition.state?.keys {
                    for key in stateKeys {
                        screenState.update(key: key, value: vm.getState(key: key))
                    }
                }
            }

            if let searchConfig = definition.search,
               let stateDefaults = definition.state,
               case .string(let defaultQuery) = stateDefaults[searchConfig.stateKey] {
                searchText = defaultQuery
            }

            vm.onStateChanged = { [screenState] key, value in
                Task { @MainActor in
                    screenState.update(key: key, value: value)
                }
            }

            screenState.syncToLua { [weak vm] key, value in
                vm?.setState(key: key, value: value)
            }

            if isNew {
                if let onMount = definition.onMount {
                    vm.executeAsync(onMount) { result in
                        if case .failure(let error) = result {
                            print("[Melody] onMount error: \(error.localizedDescription)")
                        }
                    }
                }
            }

        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Navigation Functions

    private func registerNavigationFunctions(vm: LuaVM) {
        vm.registerMelodyFunction(name: "navigate") { [navigator] args in
            if let path = args.first?.stringValue {
                if args.count >= 2, let props = args[1].tableValue {
                    navigator.navigationProps[path] = props
                }
                navigator.navigate(to: path)
            }
            return .nil
        }

        let globalNav = rootNavigator ?? navigator
        vm.registerMelodyFunction(name: "replace") { [navigator] args in
            if let path = args.first?.stringValue {
                let isLocal = args.count >= 2 && args[1].tableValue?["local"]?.boolValue == true
                if isLocal {
                    navigator.replace(with: path)
                } else {
                    globalNav.replace(with: path)
                }
            }
            return .nil
        }

        vm.registerMelodyFunction(name: "goBack") { [navigator] args in
            navigator.goBack()
            return .nil
        }

        vm.registerMelodyFunction(name: "switchTab") { [tabCoordinator] args in
            if let tabId = args.first?.stringValue {
                tabCoordinator?.switchTab(to: tabId)
            }
            return .nil
        }
    }

    // MARK: - Presentation Functions

    private func registerPresentationFunctions(vm: LuaVM) {
        vm.registerMelodyFunction(name: "alert") { [presentation] args in
            presentation.alert = .from(args: args)
            return .nil
        }

        vm.registerMelodyFunction(name: "sheet") { [presentation, navigator] args in
            guard let path = args.first?.stringValue else { return .nil }
            var detent: String? = nil
            var style: String? = nil
            var showsToolbar: Bool = true
            var sourceId: String?
            if args.count >= 2, let opts = args[1].tableValue {
                detent = opts["detent"]?.stringValue
                style = opts["style"]?.stringValue
                showsToolbar = opts["showsToolbar"]?.boolValue ?? true
                sourceId = opts["sourceId"]?.stringValue
                var props: [String: LuaValue] = [:]
                for (k, v) in opts where k != "detent" && k != "style" {
                    props[k] = v
                }
                if !props.isEmpty {
                    navigator.navigationProps[path] = props
                }
            }
            presentation.sheet = MelodySheetConfig(
                screenPath: path,
                detent: detent,
                style: style,
                showsToolbar: showsToolbar,
                sourceId: sourceId
            )
            return .nil
        }

        if let dismiss = melodyDismiss {
            vm.registerMelodyFunction(name: "dismiss") { _ in
                dismiss()
                return .nil
            }
        }
    }

    // MARK: - Utility Functions

    private func registerUtilityFunctions(vm: LuaVM) {
        vm.registerMelodyFunction(name: "clearCookies") { _ in
            HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
            return .nil
        }

        vm.registerMelodyFunction(name: "trustHost") { args in
            guard let host = args.first?.stringValue, !host.isEmpty else { return .nil }
            MelodyURLSession.shared.trustHost(host)
            return .nil
        }

        vm.registerMelodyFunction(name: "setTitle") { args in
            if let title = args.first?.stringValue {
                self.titleOverride = title
            }
            return .nil
        }

        vm.registerMelodyFunction(name: "copyToClipboard") { args in
            if let text = args.first?.stringValue {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                #elseif os(iOS)
                UIPasteboard.general.string = text
                #endif
            }
            return .nil
        }
    }

    // MARK: - WebSocket Functions

    private func registerWebSocketFunctions(vm: LuaVM) {
        vm.registerMelodyFunction(name: "_ws_connect") { [weak vm] args in
            guard let vm else { return .nil }
            guard let urlString = args.first?.stringValue,
                  let url = URL(string: urlString) else { return .nil }

            let id = self.nextWsId
            self.nextWsId += 1

            let ws = MelodyWebSocket()
            self.webSockets[id] = ws

            var headers: [String: String]? = nil
            if args.count >= 2, let h = args[1].tableValue {
                headers = [:]
                for (k, v) in h {
                    if let s = v.stringValue { headers?[k] = s }
                }
            }

            ws.onOpen = {
                vm.dispatchEvent(name: "_ws:\(id):open", data: .nil)
            }
            ws.onMessage = { text in
                if let jsonData = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData),
                   let luaValue = MelodyHTTP.jsonToLuaValue(json) {
                    vm.dispatchEvent(name: "_ws:\(id):message", data: luaValue)
                } else {
                    vm.dispatchEvent(name: "_ws:\(id):message", data: .string(text))
                }
            }
            ws.onError = { errorMsg in
                vm.dispatchEvent(name: "_ws:\(id):error", data: .string(errorMsg))
            }
            ws.onClose = { code, reason in
                vm.dispatchEvent(name: "_ws:\(id):close", data: .table([
                    "code": .number(Double(code)),
                    "reason": .string(reason ?? "")
                ]))
                self.webSockets.removeValue(forKey: id)
            }

            ws.connect(url: url, headers: headers)
            return .number(Double(id))
        }

        vm.registerMelodyFunction(name: "_ws_send") { args in
            guard args.count >= 2,
                  let id = args[0].numberValue.map({ Int($0) }),
                  let ws = self.webSockets[id] else { return .nil }

            switch args[1] {
            case .string(let text):
                ws.send(text)
            case .table, .array:
                let json = MelodyHTTP.luaValueToJSON(args[1])
                if let data = try? JSONSerialization.data(withJSONObject: json),
                   let text = String(data: data, encoding: .utf8) {
                    ws.send(text)
                }
            default:
                break
            }
            return .nil
        }

        vm.registerMelodyFunction(name: "_ws_close") { args in
            guard let id = args.first?.numberValue.map({ Int($0) }),
                  let ws = self.webSockets[id] else { return .nil }

            let code = args.count >= 2 ? args[1].numberValue.map({ Int($0) }) ?? 1000 : 1000
            let reason = args.count >= 3 ? args[2].stringValue : nil
            let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .normalClosure
            ws.close(code: closeCode, reason: reason)
            self.webSockets.removeValue(forKey: id)
            return .nil
        }

        _ = try? vm.execute("""
            _melody_ws_objects = {}
            melody.wsConnect = function(url, options)
                local headers = options and options.headers or nil
                local id = melody._ws_connect(url, headers)
                if not id then return nil end
                local ws = { id = id }
                _melody_ws_objects[id] = ws

                function ws:on(event, callback)
                    melody.on("_ws:" .. self.id .. ":" .. event, callback)
                end
                function ws:off(event, callback)
                    melody.off("_ws:" .. self.id .. ":" .. event, callback)
                end
                function ws:send(data)
                    melody._ws_send(self.id, data)
                end
                function ws:close(code, reason)
                    for _, e in ipairs({"open", "message", "error", "close"}) do
                        melody.off("_ws:" .. self.id .. ":" .. e)
                    end
                    melody._ws_close(self.id, code or 1000, reason or "")
                    _melody_ws_objects[self.id] = nil
                end
                return ws
            end
        """)
    }
}
