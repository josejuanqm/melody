import SwiftUI
import Core

// MARK: - Dynamic Tab Visibility State

@Observable
private final class DynamicTabState {
    var visibleTabs: [TabDefinition] = []
    var coordinator: TabCoordinator?

    @ObservationIgnored var vm: LuaVM?
    @ObservationIgnored var observerId: UUID?
    @ObservationIgnored var tabNavigators: [String: Navigator] = [:]
    @ObservationIgnored var vmAnchor: VMLifecycleAnchor?
}

/// Renders a tab bar from ``TabDefinition`` entries, each with its own ``Navigator``.
struct TabContainerView: View {
    let definition: ScreenDefinition
    let http: MelodyHTTP

    @Environment(\.navigator) private var parentNavigator
    @Environment(\.melodyStore) private var store
    @Environment(\.melodyEventBus) private var eventBus
    @Environment(\.customComponents) private var customComponents
    @Environment(\.themeColors) private var themeColors
    @Environment(\.appLuaPrelude) private var appLuaPrelude
    @Environment(\.pluginRegistry) private var pluginRegistry
    @Environment(\.vmRegistry) private var vmRegistry

    @Namespace private var namespace
    @State private var dynamicState = DynamicTabState()
    @State private var presentation = PresentationCoordinator()

    private var isSidebarAdaptable: Bool {
        TabStyleVariant(definition.tabStyle) == .sidebaradaptable
    }

    private static let currentPlatforms: Set<String> = {
        #if os(macOS)
        return ["macos", "desktop"]
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return ["ios", "desktop"]
        }
        return ["ios"]
        #endif
    }()

    private var hasDynamicTabs: Bool {
        definition.tabs?.contains(where: { $0.visible != nil }) ?? false
    }

    private var platformFilteredTabs: [TabDefinition] {
        definition.tabs?.filter { tab in
            guard let platforms = tab.platforms, !platforms.isEmpty else { return true }
            let lowered = Set(platforms.map { $0.lowercased() })
            return !lowered.isDisjoint(with: Self.currentPlatforms)
        } ?? []
    }

    var body: some View {
        Group {
            let tabs = dynamicState.visibleTabs
            if !tabs.isEmpty, let coordinator = dynamicState.coordinator {
                if isSidebarAdaptable {
                    if #available(iOS 18.0, macOS 15.0, visionOS 2.0, *) {
                        sidebarAdaptableTabView(tabs: tabs, coordinator: coordinator)
                    } else {
                        standardTabView(tabs: tabs, coordinator: coordinator)
                    }
                } else {
                    standardTabView(tabs: tabs, coordinator: coordinator)
                }
            } else {
                Color.clear
            }
        }
        .modifier(ScreenToolbarModifier(
            toolbarItems: definition.toolbar,
            searchConfig: nil,
            luaVM: dynamicState.vm,
            namespace: namespace
        ))
        .modifier(ScreenPresentationModifier(
            presentation: presentation,
            luaVM: dynamicState.vm,
            sheetContentBuilder: { config in
                AnyView(tabSheetContent(config: config))
            },
            namespace: namespace
        ))
        .onAppear { setupTabs() }
        .onDisappear { tearDown() }
        #if MELODY_DEV
        .onChange(of: parentNavigator.screenRegistrationVersion) { _, _ in
            reRegisterTabScreens()
        }
        #endif
    }

    @ViewBuilder
    private func tabSheetContent(config: MelodySheetConfig) -> some View {
        if let screenDef = parentNavigator.screen(for: config.screenPath) {
            NavigationStack {
                ScreenView(definition: screenDef, http: http, actualPath: config.screenPath)
                    .environment(\.melodyDismiss, { presentation.sheet = nil })
            }
            .presentationDetents(SheetDetent(config.detent) == .medium ? [.medium, .large] : [.large])
        }
    }

    // MARK: - Standard TabView (all OS versions)

    private func standardTabView(tabs: [TabDefinition], coordinator: TabCoordinator) -> some View {
        TabView(selection: Bindable(coordinator).selectedTabId) {
            ForEach(tabs, id: \.id) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab.id)
            }
        }
        .environment(\.tabCoordinator, coordinator)
    }

    // MARK: - Sidebar Adaptable TabView (iOS 18+, macOS 15+)

    private enum TabEntry: Identifiable {
        case single(TabDefinition)
        case section(String, [TabDefinition])

        var id: String {
            switch self {
            case .single(let tab): return tab.id
            case .section(let name, _): return "_section:\(name)"
            }
        }
    }

    private func groupedTabEntries(_ tabs: [TabDefinition]) -> [TabEntry] {
        var entries: [TabEntry] = []
        var i = 0
        while i < tabs.count {
            let tab = tabs[i]
            if let group = tab.group {
                var groupTabs = [tab]
                var j = i + 1
                while j < tabs.count, tabs[j].group == group {
                    groupTabs.append(tabs[j])
                    j += 1
                }
                entries.append(.section(group, groupTabs))
                i = j
            } else {
                entries.append(.single(tab))
                i += 1
            }
        }
        return entries
    }

    @available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
    private func sidebarAdaptableTabView(tabs: [TabDefinition], coordinator: TabCoordinator) -> some View {
        let entries = groupedTabEntries(tabs)
        return TabView(selection: Bindable(coordinator).selectedTabId) {
            ForEach(entries, id: \.id) { entry in
                switch entry {
                case .single(let tab):
                    Tab(tab.title, systemImage: tab.icon, value: tab.id) {
                        tabContent(for: tab)
                    }
                case .section(let name, let groupTabs):
                    TabSection(name) {
                        ForEach(groupTabs, id: \.id) { tab in
                            Tab(tab.title, systemImage: tab.icon, value: tab.id) {
                                tabContent(for: tab)
                            }
                        }
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(\.tabCoordinator, coordinator)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: TabDefinition) -> some View {
        if let nav = dynamicState.tabNavigators[tab.id] {
            TabNavigationContent(navigator: nav, rootScreenPath: tab.screen, http: http)
        }
    }

    // MARK: - Setup & Teardown

    private var tabVMKey: String {
        "_tabs:\(definition.path)"
    }

    private func setupTabs() {
        let platformTabs = platformFilteredTabs
        guard !platformTabs.isEmpty else { return }
        let allScreens = parentNavigator.registeredScreens
        let state = dynamicState

        print("[Melody:Tabs] setupTabs — hasDynamicTabs=\(hasDynamicTabs), platformTabs=\(platformTabs.map(\.id))")

        let needsVM = hasDynamicTabs || definition.onMount != nil || definition.toolbar != nil
        var isNew = false

        if needsVM && state.vm == nil {
            do {
                let anchor = state.vmAnchor ?? VMLifecycleAnchor(key: tabVMKey, registry: vmRegistry)
                if state.vmAnchor == nil { state.vmAnchor = anchor }

                let result = try vmRegistry.acquire(for: tabVMKey, anchorId: anchor.id, source: definition.title ?? definition.path)
                state.vm = result.vm
                isNew = result.isNew
                print("[Melody:Tabs] VM acquired (isNew=\(isNew))")
            } catch {
                print("[Melody:Tabs] Failed to acquire VM: \(error)")
            }
        }

        if let vm = state.vm, isNew, hasDynamicTabs {
            vm.registerMelodyFunction(name: "storeGet") { [store] args in
                guard let key = args.first?.stringValue else { return .nil }
                let val = store.get(key: key)
                print("[Melody:Tabs] storeGet('\(key)') → \(val)")
                return val
            }
        }

        let visible = evaluateTabVisibility(platformTabs, vm: state.vm)
        print("[Melody:Tabs] Initial visible tabs: \(visible.map(\.id))")
        let visibleIds = visible.map(\.id)
        if visibleIds != state.visibleTabs.map(\.id) {
            state.visibleTabs = visible
        }

        for tab in visible {
            if state.tabNavigators[tab.id] == nil {
                let nav = Navigator()
                nav.rootPath = tab.screen
                nav.registerScreens(allScreens)
                state.tabNavigators[tab.id] = nav
            }
        }

        if state.coordinator == nil {
            state.coordinator = TabCoordinator(
                tabIds: visible.map(\.id),
                initialTabId: visible[0].id
            )
        }

        if hasDynamicTabs && state.observerId == nil {
            let obsId = eventBus.observe(event: "tabVisibilityChanged") {
                [state, platformTabs, allScreens] _ in
                print("[Melody:Tabs] Observer fired — tabVisibilityChanged")
                reEvaluateVisibility(
                    state: state,
                    platformTabs: platformTabs,
                    allScreens: allScreens
                )
            }
            state.observerId = obsId
            print("[Melody:Tabs] Observer registered: \(obsId)")
        } else if hasDynamicTabs {
            print("[Melody:Tabs] Observer already registered: \(String(describing: state.observerId))")
        }

        if let vm = state.vm {
            if isNew {
                do {
                    try vm.registerCoreFunctions(
                        store: store,
                        eventBus: eventBus,
                        themeColors: themeColors,
                        pluginRegistry: pluginRegistry,
                        appLuaPrelude: appLuaPrelude
                    )
                } catch {
                    print("[Melody:Tabs] Failed to register core functions: \(error)")
                }
            }

            if let coordinator = state.coordinator {
                vm.registerMelodyFunction(name: "switchTab") { args in
                    if let tabId = args.first?.stringValue {
                        coordinator.switchTab(to: tabId)
                    }
                    return .nil
                }
            }

            let pres = presentation
            let nav = parentNavigator
            vm.registerMelodyFunction(name: "sheet") { args in
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
                    for (k, v) in opts where k != "detent" && k != "style" && k != "showsToolbar" {
                        props[k] = v
                    }
                    if !props.isEmpty {
                        nav.navigationProps[path] = props
                    }
                }
                pres.sheet = MelodySheetConfig(
                    screenPath: path,
                    detent: detent,
                    style: style,
                    showsToolbar: showsToolbar,
                    sourceId: sourceId
                )
                return .nil
            }

            vm.registerMelodyFunction(name: "alert") { args in
                pres.alert = .from(args: args)
                return .nil
            }

            if isNew {
                if let onMount = definition.onMount {
                    vm.executeAsync(onMount) { result in
                        if case .failure(let error) = result {
                            print("[Melody:Tabs] onMount error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    #if MELODY_DEV
    /// Re-register screens on all tab navigators after hot reload.
    /// Navigation stacks are preserved — each ScreenView recreates itself
    /// via the version-keyed `.id()` to pick up the new definition.
    private func reRegisterTabScreens() {
        let updatedScreens = parentNavigator.registeredScreens
        let state = dynamicState

        // Update screen definitions on existing tab navigators (bumps their version)
        for (_, nav) in state.tabNavigators {
            nav.registerScreens(updatedScreens)
        }

        // Re-evaluate tab visibility in case tabs were added/removed
        let platformTabs = platformFilteredTabs
        let newVisible = evaluateTabVisibility(platformTabs, vm: state.vm)
        let newIds = newVisible.map(\.id)

        for tab in newVisible where state.tabNavigators[tab.id] == nil {
            let nav = Navigator()
            nav.rootPath = tab.screen
            nav.registerScreens(updatedScreens)
            state.tabNavigators[tab.id] = nav
        }

        state.visibleTabs = newVisible
        state.coordinator?.updateTabIds(newIds)
    }
    #endif

    private func tearDown() {
        if let id = dynamicState.observerId {
            eventBus.removeObserver(id)
            dynamicState.observerId = nil
        }
        dynamicState.vm = nil
    }

    // MARK: - Expression Evaluation

    private func evaluateTabVisibility(
        _ platformTabs: [TabDefinition],
        vm: LuaVM?
    ) -> [TabDefinition] {
        let resolver = ExpressionResolver(vm: vm, props: nil)
        return platformTabs.filter { tab in
            resolver.visible(tab.visible)
        }
    }

    private func reEvaluateVisibility(
        state: DynamicTabState,
        platformTabs: [TabDefinition],
        allScreens: [ScreenDefinition]
    ) {
        let oldIds = state.visibleTabs.map(\.id)
        let newVisible = evaluateTabVisibility(platformTabs, vm: state.vm)
        let newIds = newVisible.map(\.id)
        print("[Melody:Tabs] reEvaluateVisibility — old=\(oldIds) new=\(newIds)")

        guard oldIds != newIds else {
            print("[Melody:Tabs] reEvaluateVisibility — no change, skipping")
            return
        }

        for tab in newVisible {
            if state.tabNavigators[tab.id] == nil {
                let nav = Navigator()
                nav.rootPath = tab.screen
                nav.registerScreens(allScreens)
                state.tabNavigators[tab.id] = nav
                print("[Melody:Tabs] Created navigator for new tab '\(tab.id)'")
            }
        }

        for (_, nav) in state.tabNavigators {
            if !nav.path.isEmpty {
                nav.path = []
            }
        }

        state.visibleTabs = newVisible
        state.coordinator?.updateTabIds(newIds)
        print("[Melody:Tabs] Updated coordinator tabIds=\(state.coordinator?.tabIds ?? [])")
    }
}

private struct TabNavigationContent: View {
    @Bindable var navigator: Navigator
    let rootScreenPath: String
    let http: MelodyHTTP

    var body: some View {
        NavigationStack(path: $navigator.path) {
            if let rootScreen = navigator.screen(for: rootScreenPath) {
                ScreenView(definition: rootScreen, http: http)
                    .id(screenViewId(rootScreenPath))
                    .navigationDestination(for: String.self) { path in
                        if let screen = navigator.screen(for: path) {
                            ScreenView(definition: screen, http: http, actualPath: path)
                                .environment(\.navigator, navigator)
                        }
                    }
            }
        }
        .environment(\.navigator, navigator)
    }

    private func screenViewId(_ path: String) -> String {
        #if MELODY_DEV
        "\(path)_v\(navigator.screenRegistrationVersion)"
        #else
        path
        #endif
    }
}
