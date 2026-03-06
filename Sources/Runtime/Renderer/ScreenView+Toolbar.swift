import SwiftUI
import Core

// MARK: - Toolbar View Builders (free functions)

@ViewBuilder
func melodyToolbarComponent(_ item: ComponentDefinition, vm: LuaVM) -> some View {
    let resolver = ExpressionResolver(vm: vm, props: nil, state: nil)
    if resolver.visible(item.visible) {
        melodyToolbarComponentContent(item, vm: vm)
    }
}

@ViewBuilder
private func melodyToolbarComponentContent(_ item: ComponentDefinition, vm: LuaVM) -> some View {
    let resolver = ExpressionResolver(vm: vm, props: nil, state: nil)
    let resolved = resolveToolbarString(item.systemImage, vm: vm)
    switch ComponentType(item.component) {
    case .menu:
        Menu {
            if let children = item.children {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    melodyToolbarMenuChild(child, vm: vm)
                }
            }
        } label: {
            if let systemImage = resolved {
                let label = resolveToolbarString(item.label, vm: vm) ?? ""
                if label.isEmpty {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color(hex: resolver.string(item.style?.color ?? .expression("theme.textPrimary"))))
                } else {
                    Label(label, systemImage: systemImage)
                        .foregroundStyle(Color(hex: resolver.string(item.style?.color ?? .expression("theme.textPrimary"))))
                }
            } else {
                Text(resolveToolbarString(item.label, vm: vm)
                     ?? resolveToolbarString(item.text, vm: vm)
                     ?? "")
                .foregroundStyle(Color(hex: resolver.string(item.style?.color ?? .expression("theme.textPrimary"))))
            }
        }
        .foregroundStyle(Color(hex: resolver.string(item.style?.color ?? .expression("theme.textPrimary"))))
    default:
        Button {
            if let script = item.onTap {
                vm.executeAsync(script) { result in
                    if case .failure(let error) = result {
                        print("[Melody] Toolbar action error: \(error.localizedDescription)")
                    }
                }
            }
        } label: {
            if let systemImage = resolved {
                Image(systemName: systemImage)
                    .foregroundStyle(Color(hex: resolver.string(item.style?.color ?? .expression("theme.textPrimary"))))
            } else {
                Text(resolveToolbarString(item.label, vm: vm)
                     ?? resolveToolbarString(item.text, vm: vm)
                     ?? "")
                .foregroundStyle(Color(hex: resolver.string(item.style?.color ?? .expression("theme.textPrimary"))))
            }
        }
    }
}

@ViewBuilder
func melodyToolbarMenuChild(_ child: ComponentDefinition, vm: LuaVM) -> some View {
    let resolver = ExpressionResolver(vm: vm, props: nil, state: nil)
    if resolver.visible(child.visible) {
        melodyToolbarMenuChildContent(child, vm: vm)
            .foregroundStyle(Color(hex: resolver.string(child.style?.color ?? .expression("theme.textPrimary"))))
    }
}

@ViewBuilder
private func melodyToolbarMenuChildContent(_ child: ComponentDefinition, vm: LuaVM) -> some View {
    let resolvedImage = resolveToolbarString(child.systemImage, vm: vm)
    Button {
        if let script = child.onTap {
            vm.executeAsync(script) { result in
                if case .failure(let error) = result {
                    print("[Melody] Menu action error: \(error.localizedDescription)")
                }
            }
        }
    } label: {
        let label = resolveToolbarString(child.label, vm: vm)
                    ?? resolveToolbarString(child.text, vm: vm)
                    ?? ""
        if let systemImage = resolvedImage {
            Label(label, systemImage: systemImage)
        } else {
            Text(label)
        }
    }
}

// MARK: - Screen Toolbar Modifier

struct ScreenToolbarModifier: ViewModifier {
    let toolbarItems: [ComponentDefinition]?
    let searchConfig: SearchConfig?
    let luaVM: LuaVM?
    let namespace: Namespace.ID

    private func splitAtSpacer(_ items: [ComponentDefinition]) -> (before: [ComponentDefinition], after: [ComponentDefinition], hasSpacer: Bool) {
        guard let idx = items.firstIndex(where: { ComponentType($0.component) == .spacer }) else {
            return (items, [], false)
        }
        return (Array(items.prefix(upTo: idx)), Array(items.suffix(from: idx + 1)), true)
    }

    func body(content: Content) -> some View {
        content.toolbar {
            if let toolbarItems, let vm = luaVM {
                if #available(iOS 26.0, macOS 26.0, *) {
                    let split = splitAtSpacer(toolbarItems)
                    melodyToolbarItemGroup(split.before, vm: vm)
                    if split.hasSpacer {
                        #if !os(tvOS) && !os(visionOS)
                        ToolbarSpacer(.fixed)
                        #endif
                        melodyToolbarItemGroup(split.after, vm: vm)
                    }
                } else {
                    ToolbarItemGroup(placement: .primaryAction) {
                        let nonSpacers = toolbarItems.filter { $0.component.lowercased() != "spacer" }
                        ForEach(Array(nonSpacers.enumerated()), id: \.offset) {
                            _,
                            item in
                            melodyToolbarComponent(item, vm: vm)
                                .modifier(
                                    MatchedTransitionSourceModifier(
                                        namespace: namespace,
                                        usesSharedObjectTransition: item.usesSharedObjectTransition ?? false,
                                        hashable: item.id
                                    )
                                )
                        }
                    }
                }
            }
            #if !os(macOS) && !os(tvOS) && !os(visionOS)
            if #available(iOS 26.0, *) {
                if let searchConfig {
                    searchToolbarItems(config: searchConfig)
                }
            }
            #endif
        }
    }

    @ToolbarContentBuilder
    private func melodyToolbarItemGroup(_ items: [ComponentDefinition], vm: LuaVM) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                melodyToolbarComponent(item, vm: vm)
                    .modifier(
                        MatchedTransitionSourceModifier(
                            namespace: namespace,
                            usesSharedObjectTransition: item.usesSharedObjectTransition ?? false,
                            hashable: item.id
                        )
                    )
            }
        }
    }

    #if !os(macOS) && !os(tvOS) && !os(visionOS)
    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    private func searchToolbarItems(config: SearchConfig) -> some ToolbarContent {
        switch ToolbarPlacementVariant(config.placement) {
        case .bottomBar:
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        case .automatic:
            ToolbarItem(placement: .automatic) { EmptyView() }
        }
    }
    #endif
}

