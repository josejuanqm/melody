import SwiftUI
import Core

/// The root view that renders an entire Melody app from an AppDefinition
public struct MelodyAppView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var currentApp: AppDefinition
    @State private var navigator = Navigator()
    @State private var store = MelodyStore()
    @State private var eventBus = MelodyEventBus()
    @State private var vmRegistry = LuaVMRegistry()
    private let http = MelodyHTTP()
    private let pluginRegistry: MelodyPluginRegistry
    private let assetBaseURL: String?

    #if MELODY_DEV
    @State private var hotReload = HotReloadClient()
    @State private var showDevSettings = false
    @State private var devSettings = DevSettings()
    #endif

    public init(appDefinition: AppDefinition, plugins: [MelodyPlugin] = [], assetBaseURL: String? = nil, store: MelodyStore = MelodyStore()) {
        self._currentApp = State(initialValue: appDefinition)
        self._store = State(initialValue: store)
        self.pluginRegistry = MelodyPluginRegistry(plugins: plugins)
        self.assetBaseURL = assetBaseURL
        navigator.registerScreens(currentApp.screens)
    }

    public var body: some View {
        Group {
            if let rootScreen = navigator.screen(for: navigator.rootPath) ?? currentApp.screens.first {
                if rootScreen.tabs != nil {
                    screenContent(for: rootScreen)
                        .id(navigator.rootPath)
                } else {
                    NavigationStack(path: $navigator.path) {
                        screenContent(for: rootScreen)
                            .id(rootScreenId)
                            .navigationDestination(for: String.self) { path in
                                if let screen = navigator.screen(for: path) {
                                    screenContent(for: screen, actualPath: path)
                                } else {
                                    Text("Screen not found: \(path)")
                                }
                            }
                    }
                }
            } else {
                Text("No screens defined")
            }
        }
        .environment(\.navigator, navigator)
        .environment(\.rootNavigator, navigator)
        .environment(\.melodyStore, store)
        .environment(\.melodyEventBus, eventBus)
        .environment(\.customComponents, currentApp.components ?? [:])
        .environment(\.themeColors, mergedThemeColors)
        .environment(\.appLuaPrelude, currentApp.app.lua)
        .environment(\.pluginRegistry, pluginRegistry)
        .environment(\.vmRegistry, vmRegistry)
        .environment(\.assetBaseURL, assetBaseURL)
        #if os(macOS)
        .frame(
            minWidth: currentApp.app.window?.minWidth.map { CGFloat($0) },
            idealWidth: currentApp.app.window?.idealWidth.map { CGFloat($0) },
            maxWidth: currentApp.app.window != nil ? .infinity : nil,
            minHeight: currentApp.app.window?.minHeight.map { CGFloat($0) },
            idealHeight: currentApp.app.window?.idealHeight.map { CGFloat($0) },
            maxHeight: currentApp.app.window != nil ? .infinity : nil
        )
        #endif
        #if MELODY_DEV
        .environment(\.devModeConnected, hotReload.isConnected)
        #endif
        .tint(accentColor)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            #if MELODY_DEV
            if devSettings.hotReloadEnabled {
                hotReload.connect(host: devSettings.devServerHost, port: devSettings.devServerPort)
            }
            _ = eventBus.observe(event: "showDevSettings") { _ in
                showDevSettings = true
            }
            #endif
        }
        #if MELODY_DEV
        .onShake {
            showDevSettings.toggle()
        }
        .sheet(isPresented: $showDevSettings) {
            DevSettingsView(
                settings: devSettings,
                logger: DevLogger.shared,
                hotReload: hotReload,
                onReconnect: {
                    hotReload.disconnect()
                    if devSettings.hotReloadEnabled {
                        hotReload.connect(host: devSettings.devServerHost, port: devSettings.devServerPort)
                    }
                }
            )
        }
        .onChange(of: devSettings.hotReloadEnabled) { _, enabled in
            if enabled {
                hotReload.connect(host: devSettings.devServerHost, port: devSettings.devServerPort)
            } else {
                hotReload.disconnect()
            }
        }
        .onChange(of: hotReload.reloadCount) { _, _ in
            if let newApp = hotReload.latestApp {
                currentApp = newApp
                navigator.registerScreens(newApp.screens)
            }
        }
        #endif
    }

    private var rootScreenId: String {
        #if MELODY_DEV
        "\(navigator.rootPath)_v\(navigator.screenRegistrationVersion)"
        #else
        navigator.rootPath
        #endif
    }

    @ViewBuilder
    private func screenContent(for screen: ScreenDefinition, actualPath: String? = nil) -> some View {
        if screen.tabs != nil {
            TabContainerView(definition: screen, http: http)
        } else {
            ScreenView(definition: screen, http: http, actualPath: actualPath)
        }
    }

    private var mergedThemeColors: [String: String] {
        var colors: [String: String] = [:]
        if let primary = currentApp.app.theme?.primary { colors["primary"] = primary }
        if let secondary = currentApp.app.theme?.secondary { colors["secondary"] = secondary }
        if let background = currentApp.app.theme?.background { colors["background"] = background }
        if let custom = currentApp.app.theme?.colors {
            for (key, value) in custom { colors[key] = value }
        }
        let activeMode: ColorScheme = {
            switch ColorSchemePreference(currentApp.app.theme?.colorScheme) {
            case .dark: return .dark
            case .light: return .light
            case .system: return systemColorScheme
            }
        }()
        let override = activeMode == .dark ? currentApp.app.theme?.dark : currentApp.app.theme?.light
        if let override {
            if let primary = override.primary { colors["primary"] = primary }
            if let secondary = override.secondary { colors["secondary"] = secondary }
            if let background = override.background { colors["background"] = background }
            if let custom = override.colors {
                for (key, value) in custom { colors[key] = value }
            }
        }
        return colors
    }

    private var accentColor: Color? {
        guard let hex = currentApp.app.theme?.primary else { return nil }
        return Color(hex: hex)
    }

    private var preferredScheme: ColorScheme? {
        switch ColorSchemePreference(currentApp.app.theme?.colorScheme) {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}
