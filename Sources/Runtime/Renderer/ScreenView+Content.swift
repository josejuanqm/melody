import SwiftUI
import Core

// MARK: - Content Wrapping

extension ScreenView {

    var effectiveWrapper: ScreenWrapper {
        if let wrapper = definition.wrapper {
            return ScreenWrapper(wrapper)
        }
        if definition.scrollEnabled == true || definition.search != nil {
            return .scroll
        }
        return .vstack
    }

    var contentInsetPadding: EdgeInsets {
        guard let inset = definition.contentInset else { return EdgeInsets() }
        return EdgeInsets(
            top: CGFloat(inset.resolvedTop),
            leading: CGFloat(inset.resolvedLeading),
            bottom: CGFloat(inset.resolvedBottom),
            trailing: CGFloat(inset.resolvedTrailing)
        )
    }

    @ViewBuilder
    var wrappedContent: some View {
        let base = baseContent
        let searchable = applySearchable(base)
        applyRefreshable(searchable)
    }

    @ViewBuilder
    private var baseContent: some View {
        switch effectiveWrapper {
        case .form:
            formStyled(
                Form {
                    ComponentRenderer(components: definition.body ?? [])
                }
                .environment(\.isInFormContext, true)
            )
        case .scroll:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ComponentRenderer(components: definition.body ?? [])
                }
                .padding(contentInsetPadding)
            }
        case .vstack:
            VStack(alignment: .leading, spacing: 0) {
                ComponentRenderer(components: definition.body ?? [])
            }
            .padding(contentInsetPadding)
        }
    }

    @ViewBuilder
    private func applySearchable(_ content: some View) -> some View {
        if let searchConfig = definition.search {
            searchableContent(content, config: searchConfig)
                .scrollClipDisabled()
        } else {
            content
        }
    }

    @ViewBuilder
    private func applyRefreshable(_ content: some View) -> some View {
        if definition.onRefresh != nil {
            content
                .refreshable {
                    guard let vm = luaVM, let script = definition.onRefresh else { return }
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        vm.executeAsync(script) { _ in
                            continuation.resume()
                        }
                    }
                }
        } else {
            content
        }
    }

    @ViewBuilder
    func formStyled(_ view: some View) -> some View {
        switch FormVariant(definition.formStyle) {
        case .grouped:
            view.formStyle(.grouped)
        case .columns:
            #if os(macOS)
            view.formStyle(.columns)
            #else
            view
            #endif
        case .automatic:
            view.formStyle(.grouped)
                .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Searchable

    @ViewBuilder
    func searchableContent<Content: View>(_ content: Content, config: SearchConfig) -> some View {
        let base = content
            .searchable(text: $searchText, prompt: config.prompt ?? "Search")
            .onChange(of: searchText) { _, newValue in
                screenState.set(key: config.stateKey, value: .string(newValue))
            }
            .onSubmit(of: .search) {
                if let script = config.onSubmit, let vm = luaVM {
                    vm.setState(key: config.stateKey, value: .string(searchText))
                    vm.executeAsync(script) { result in
                        if case .failure(let error) = result {
                            print("[Melody] Search submit error: \(error.localizedDescription)")
                        }
                    }
                }
            }

        #if !os(macOS) && !os(tvOS) && !os(visionOS) && !os(visionOS)
        if #available(iOS 26.0, *), config.minimized == true {
            base.searchToolbarBehavior(.minimize)
        } else {
            base
        }
        #else
        base
        #endif
    }

    // MARK: - Pull to Refresh (inlined into applyRefreshable above)

    // MARK: - Search Toolbar Items (iOS 26+)

    #if !os(macOS) && !os(tvOS) && !os(visionOS)
    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    func searchToolbarItems(config: SearchConfig) -> some ToolbarContent {
        switch ToolbarPlacementVariant(config.placement) {
        case .bottomBar:
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        case .automatic:
            ToolbarItem(placement: .automatic) { EmptyView() }
        }
    }
    #endif
}
