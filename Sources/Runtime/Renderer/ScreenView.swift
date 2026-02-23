import SwiftUI
import Core

/// Renders a single screen from a ``ScreenDefinition``, managing its Lua VM and state lifecycle.
struct ScreenView: View {
    let definition: ScreenDefinition
    let http: MelodyHTTP
    var actualPath: String? = nil

    @Environment(\.navigator) var navigator
    @Environment(\.rootNavigator) var rootNavigator
    @Environment(\.melodyStore) var store
    @Environment(\.themeColors) var themeColors
    @Environment(\.devModeConnected) var devModeConnected
    @Environment(\.tabCoordinator) var tabCoordinator
    @Environment(\.melodyDismiss) var melodyDismiss
    @Environment(\.appLuaPrelude) var appLuaPrelude
    @Environment(\.melodyEventBus) var eventBus
    @Environment(\.pluginRegistry) var pluginRegistry
    @Environment(\.vmRegistry) var vmRegistry
    @Namespace var namespace

    @State var screenState = ScreenState()
    @State var luaVM: LuaVM?
    @State var error: String?
    @State var searchText: String = ""
    @State var presentation = PresentationCoordinator()
    @State var preparePending: Bool = true
    @State var titleOverride: String?
    @State var webSockets: [Int: MelodyWebSocket] = [:]
    @State var nextWsId: Int = 1
    @State var vmAnchor: VMLifecycleAnchor?

    private var tintColor: Color {
        return Color(hex: StyleResolver.colorHex("primary", themeColors: themeColors)).opacity(0.5)
    }

    var body: some View {
        screenContent
            .background {
                if screenState.get(key: "loading").boolValue ?? false, definition.showsLoadingIndicator ?? true {
                    ZStack(alignment: .center) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(tintColor.opacity(0.5))
                    }
                }
            }
            .environment(\.screenState, screenState)
            .environment(\.luaVM, luaVM)
            .modifier(ScreenPresentationModifier(
                presentation: presentation,
                luaVM: luaVM,
                sheetContentBuilder: { config in
                    AnyView(sheetContent(config: config))
                },
                namespace: namespace
            ))
            .navigationTitle(titleOverride ?? definition.title ?? definition.id)
            .modifier(TitleMenuModifier(items: definition.titleMenu, builder: definition.titleMenuBuilder, luaVM: luaVM))
            #if !os(macOS)
            .modifier(TitleDisplayModeModifier(mode: definition.titleDisplayMode))
            #endif
            .modifier(ScreenToolbarModifier(
                toolbarItems: definition.toolbar,
                searchConfig: definition.search,
                luaVM: luaVM,
                namespace: namespace
            ))
            .task {
                guard preparePending else {
                    return
                }
                preparePending = false
                setupScreen()
            }
            .onDisappear {
                for ws in webSockets.values {
                    ws.disconnect()
                }
                webSockets.removeAll()
            }
    }

    @ViewBuilder
    private var screenContent: some View {
        if let error = error {
            errorOverlay(error)
        } else if luaVM != nil {
            wrappedContent
        } else {
            Color.clear
        }
    }
}
