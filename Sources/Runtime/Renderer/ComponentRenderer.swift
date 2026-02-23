import SwiftUI
import Core

// MARK: - Form Context Environment Key

private struct FormContextKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isInFormContext: Bool {
        get { self[FormContextKey.self] }
        set { self[FormContextKey.self] = newValue }
    }
}

// MARK: - Stack Context Environment Key

private struct StackContextKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isInStackContext: Bool {
        get { self[StackContextKey.self] }
        set { self[StackContextKey.self] = newValue }
    }
}

/// Iterates a list of ``ComponentDefinition`` values and renders each as a SwiftUI view.
struct ComponentRenderer: View {
    let components: [ComponentDefinition]

    var body: some View {
        ForEach(Array(components.enumerated()), id: \.offset) { _, component in
            componentOrSpacer(component)
        }
    }

    @ViewBuilder
    private func componentOrSpacer(_ component: ComponentDefinition) -> some View {
        if ComponentType(component.component) == .spacer {
            Spacer()
        } else {
            BoundComponentView(definition: component)
                .controlSize(.regular)
        }
    }
}

/// Observes only the state keys referenced by this component's expressions,
/// then renders the component. Static components (no state.xxx references)
/// never re-render from state changes.
struct BoundComponentView: View {
    let definition: ComponentDefinition

    @Environment(\.screenState) private var screenState
    @Environment(\.luaVM) private var luaVM
    @Environment(\.navigator) private var navigator
    @Environment(\.localState) private var localState
    @Environment(\.customComponents) private var customComponents
    @Environment(\.componentProps) private var componentProps
    @Environment(\.isInFormContext) private var isInFormContext
    @Environment(\.isInStackContext) private var isInStackContext
    @Environment(\.namespace) private var namespace

    #if os(tvOS)
    @FocusState var focused
    #endif

    private var resolver: ExpressionResolver {
        // To avoid using expressionresolver as main actor, send state as a value
        ExpressionResolver(
            vm: luaVM,
            props: componentProps,
            state: screenState.allValues
        )
    }

    var body: some View {
        let _ = observeBindings()
        let _ = setupScope()
        let resolved = resolvedDefinition
        let vis = resolver.visible(resolved.visible)

        if resolved.transition != nil {
            Group {
                if vis {
                    visibleContent(resolved)
                        .transition(resolver.transition(resolved.transition))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vis)
            .modifier(
                MatchedTransitionSourceModifier(
                    namespace: namespace,
                    usesSharedObjectTransition: definition.usesSharedObjectTransition ?? false,
                    hashable: definition.id
                )
            )
        } else {
            if vis {
                visibleContent(resolved)
                    .modifier(
                        MatchedTransitionSourceModifier(
                            namespace: namespace,
                            usesSharedObjectTransition: definition.usesSharedObjectTransition ?? false,
                            hashable: definition.id
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private func visibleContent(_ resolved: ComponentDefinition) -> some View {
        let radius = resolved.style?.cornerRadius.resolved ?? resolved.style?.borderRadius.resolved ?? 0
        let rendered = componentBody(resolved)
            .id(resolved.id)
            .backgroundComponent(resolved.background, cornerRadius: radius)

        let componentType = ComponentType(resolved.component)
        let handlesOwnTap = componentType == .button || componentType == .stack
        let isDisabled = resolver.disabled(resolved.disabled)
        let base = Group {
            if let onTap = resolved.onTap, !handlesOwnTap {
                Button(action: { executeLua(onTap) }) {
                    rendered
                }
                .buttonStyle(.plain)
            } else {
                rendered
            }
        }
        .disabled(isDisabled)
        let hasContextMenu = !(resolved.contextMenu ?? []).isEmpty

        if let hoverScript = resolved.onHover {
            let prefix = resolver.propsPrefix()
            #if os(tvOS)
            let hoverable = base
                .focused($focused)
                .onChange(of: focused) {
                    let isHovered = focused
                    guard let vm = luaVM else { return }
                    setupScope()
                    vm.executeAsync(prefix + "local hovered = \(isHovered)\n\(hoverScript)") { result in
                        if case .failure(let error) = result {
                            print("[Melody] Hover error: \(error.localizedDescription)")
                        }
                    }
                }
            if hasContextMenu {
                hoverable.contextMenu { contextMenuContent(resolved.contextMenu!) }
            } else {
                hoverable
            }
            #else
            let hoverable = base
                .onHover { isHovered in
                    guard let vm = luaVM else { return }
                    setupScope()
                    vm.executeAsync(prefix + "local hovered = \(isHovered)\n\(hoverScript)") { result in
                        if case .failure(let error) = result {
                            print("[Melody] Hover error: \(error.localizedDescription)")
                        }
                    }
                }
            if hasContextMenu {
                hoverable.contextMenu { contextMenuContent(resolved.contextMenu!) }
            } else {
                hoverable
            }
            #endif
        } else if hasContextMenu {
            base.contextMenu { contextMenuContent(resolved.contextMenu!) }
        } else {
            base
        }
    }

    private var resolvedDefinition: ComponentDefinition {
        var resolved = definition
        resolved.style = resolver.style(definition.style)
        return resolved
    }

    /// Touch each bound slot's value so SwiftUI tracks only those keys
    private func observeBindings() {
        let bindings = BindingExtractor.bindings(for: definition)
        for key in bindings.stateKeys {
            _ = screenState.slot(for: key).value
        }
        if let localState {
            for key in bindings.scopeKeys {
                _ = localState.slot(for: key).value
            }
        }
    }

    /// Sync localState → Lua scope table before any Lua evaluation.
    /// Uses allValuesUntracked so this doesn't register @Observable tracking
    /// on every scope slot — observation is handled by observeBindings() instead.
    @discardableResult
    private func setupScope() -> Bool {
        guard let vm = luaVM else { return false }
        vm.clearScope()
        if let localState {
            for (key, value) in localState.allValuesUntracked {
                vm.setScopeState(key: key, value: value)
            }
            vm.onScopeChanged = { [localState] key, value in
                localState.update(key: key, value: value)
            }
        }
        return true
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(_ items: [ContextMenuItem]) -> some View {
        let groups = groupBySections(items)
        ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
            Section {
                ForEach(Array(group.enumerated()), id: \.offset) { _, item in
                    Button(role: item.style == "destructive" ? .destructive : nil) {
                        executeLua(item.onTap)
                    } label: {
                        if let image = item.systemImage, !image.isEmpty {
                            Label(item.label, systemImage: image)
                        } else {
                            Text(item.label)
                        }
                    }
                }
            }
        }
    }

    /// Splits context menu items at `section = true` markers into groups of regular items.
    private func groupBySections(_ items: [ContextMenuItem]) -> [[ContextMenuItem]] {
        var groups: [[ContextMenuItem]] = [[]]
        for item in items {
            if item.section == true {
                if !groups[groups.count - 1].isEmpty {
                    groups.append([])
                }
            } else {
                groups[groups.count - 1].append(item)
            }
        }
        return groups.filter { !$0.isEmpty }
    }

    // MARK: - Component Body

    @ViewBuilder
    private func componentBody(_ definition: ComponentDefinition) -> some View {
        switch ComponentType(definition.component) {
        case .text:
            MelodyText(
                definition: definition,
                resolvedText: resolver.string(definition.text)
            )

        case .button:
            MelodyButton(
                definition: definition,
                resolvedLabel: resolver.string(definition.label),
                resolvedSystemImage: definition.systemImage != nil ? resolver.string(definition.systemImage) : nil,
                onTap: { executeLua(definition.onTap) }
            )

        case .group where isInFormContext:
            Group {
                if let children = definition.children {
                    ComponentRenderer(components: children)
                }
                renderDynamicItems(definition)
            }

        case .stack, .group:
            if let onTap = definition.onTap {
                Button(action: { executeLua(onTap) }) {
                    MelodyStack(definition: definition, resolvedDirection: resolver.direction(definition.direction)) {
                        if let children = definition.children {
                            ComponentRenderer(components: children)
                        }
                        renderDynamicItems(definition)
                    }
                }
                .buttonStyle(.plain)
            } else {
                MelodyStack(definition: definition, resolvedDirection: resolver.direction(definition.direction)) {
                    if let children = definition.children {
                        ComponentRenderer(components: children)
                    }
                    renderDynamicItems(definition)
                }
            }

        case .image:
            MelodyImage(
                definition: definition,
                resolvedSrc: definition.src != nil ? resolver.string(definition.src) : nil,
                resolvedSystemImage: definition.systemImage != nil ? resolver.string(definition.systemImage) : nil
            )

        case .input:
            let inputValue: String = {
                if definition.value != nil {
                    return resolver.string(definition.value)
                }
                return ""
            }()
            MelodyInput(
                definition: definition,
                resolvedLabel: resolver.string(definition.label),
                resolvedValue: inputValue,
                onChanged: { newValue in
                    if let key = definition.stateKey {
                        screenState.set(key: key, value: .string(newValue))
                    }
                    if let handler = definition.onChanged {
                        luaVM?.setStateRaw(key: "_input_value", value: .string(newValue))
                        executeLua("local value = state._input_value\n\(handler)")
                    }
                },
                onSubmit: definition.onSubmit != nil ? {
                    executeLua(definition.onSubmit)
                } : nil
            )

        case .list:
            renderList(definition)

        case .grid:
            renderGrid(definition)

        case .stateProvider:
            StateProviderView(definition: definition)

        case .spacer:
            MelodySpacer()

        case .activity:
            ProgressView()
                .melodyStyle(definition.style)

        case .toggle:
            MelodyToggle(
                definition: definition,
                onChanged: definition.onChanged != nil ? {
                    executeLua(definition.onChanged)
                } : nil
            )

        case .divider:
            Divider()

        case .picker:
            MelodyPicker(
                definition: definition,
                resolvedOptions: resolver.options(definition.options),
                onChanged: definition.onChanged != nil ? { _ in
                    executeLua(definition.onChanged)
                } : nil
            )

        case .slider:
            #if os(tvOS)
            Text("Unavailable component \(definition.component)")
            #else
            MelodySlider(
                definition: definition,
                onChanged: definition.onChanged != nil ? {
                    executeLua(definition.onChanged)
                } : nil
            )
            #endif

        case .progress:
            MelodyProgress(
                definition: definition,
                resolvedValue: definition.value != nil ? resolver.string(definition.value) : nil,
                resolvedLabel: definition.label != nil ? resolver.string(definition.label) : nil
            )

        case .stepper:
            #if os(tvOS)
            Text("Unavailable component \(definition.component)")
            #else
            MelodyStepper(
                definition: definition,
                resolvedLabel: resolver.string(definition.label),
                onChanged: definition.onChanged != nil ? {
                    executeLua(definition.onChanged)
                } : nil
            )
            #endif

        case .datepicker:
            #if os(tvOS)
            Text("Unavailable component \(definition.component)")
            #else
            MelodyDatePicker(
                definition: definition,
                onChanged: definition.onChanged != nil ? {
                    executeLua(definition.onChanged)
                } : nil
            )
            #endif

        case .menu:
            MelodyMenu(
                definition: definition,
                resolvedLabel: resolver.string(definition.label),
                resolvedSystemImage: definition.systemImage != nil ? resolver.string(definition.systemImage) : nil
            ) {
                if let children = definition.children {
                    ComponentRenderer(components: children)
                }
            }

        case .link:
            MelodyLink(
                definition: definition,
                resolvedLabel: resolver.string(definition.label),
                resolvedURL: resolver.string(definition.url),
                resolvedSystemImage: definition.systemImage != nil ? resolver.string(definition.systemImage) : nil
            )

        case .disclosure:
            MelodyDisclosure(definition: definition, resolvedLabel: resolver.string(definition.label)) {
                if let children = definition.children {
                    ComponentRenderer(components: children)
                }
            }

        case .scroll:
            ScrollView(resolver.direction(definition.direction) == .horizontal ? .horizontal : .vertical,
                        showsIndicators: true) {
                if let children = definition.children {
                    ComponentRenderer(components: children)
                }
                renderDynamicItems(definition)
            }
            .melodyStyle(definition.style)

        case .form:
            MelodyForm(definition: definition) {
                if let children = definition.children {
                    ComponentRenderer(components: children)
                }
                renderDynamicItems(definition)
            }

        case .section:
            MelodySection(
                definition: definition,
                resolvedLabel: resolver.string(definition.label),
                resolvedFooter: resolver.string(definition.footer),
                headerContent: definition.header,
                footerComponents: definition.footerContent
            ) {
                if let children = definition.children {
                    ComponentRenderer(components: children)
                }
                renderDynamicItems(definition)
            }

        case .chart:
            MelodyChart(
                definition: definition,
                resolvedItems: resolver.items(definition.items)
            )

        default:
            if let template = customComponents[definition.component] {
                CustomComponentView(template: template, instanceProps: definition.props)
            } else {
                Text("Unknown component: \(definition.component)")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Pre-resolved List Item

    private struct RenderedListItem: Identifiable {
        let id: String
        let components: [ComponentDefinition]
    }

    private func preResolveItems(_ definition: ComponentDefinition) -> [RenderedListItem] {
        let items = resolver.items(definition.items)
        guard let script = definition.render else { return [] }
        return items.enumerated().map { index, item in
            // Pass a 1-based index since lua handles indices this way
            let comps = resolveRenderFunction(item: item, index: index + 1, script: script)
            let stableId = comps.first?.id ?? "\(index)"
            return RenderedListItem(id: stableId, components: comps)
        }
    }

    // MARK: - List Rendering

    @ViewBuilder
    private func renderList(_ definition: ComponentDefinition) -> some View {
        let rendered = preResolveItems(definition)
        let spacing = definition.style?.spacing.resolved.map { CGFloat($0) } ?? 8
        let anim = StyleResolver.animation(definition.style?.animation)
        let ids = rendered.map(\.id)

        if resolver.direction(definition.direction) == .horizontal {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: spacing) {
                    ForEach(rendered) { item in
                        renderedItemContent(item)
                    }
                }
                .melodyStyle(definition.style)
                .maybeAnimate(anim, value: ids)
            }
            .scrollClipDisabled(OverflowMode(definition.style?.overflow) == .visible)
        } else if isInFormContext {
            ForEach(rendered) { item in
                renderedItemContent(item)
            }
            .maybeAnimate(anim, value: ids)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: spacing) {
                    ForEach(rendered) { item in
                        renderedItemContent(item)
                    }
                }
                .melodyStyle(definition.style)
                .maybeAnimate(anim, value: ids)
            }
            .scrollClipDisabled(OverflowMode(definition.style?.overflow) == .visible)
        }
    }

    // MARK: - Grid Rendering

    @ViewBuilder
    private func renderGrid(_ definition: ComponentDefinition) -> some View {
        let rendered = preResolveItems(definition)
        let columns = resolver.number(definition.columns).map(Int.init) ?? 2
        let spacing = definition.style?.spacing.resolved.map { CGFloat($0) } ?? 8
        let min = resolver.number(definition.minColumnWidth) ?? resolver.number(definition.maxColumnWidth) ?? 0
        let max = resolver.number(definition.maxColumnWidth) ?? resolver.number(definition.minColumnWidth) ?? 0
        let gridItems: [GridItem] = Array(
            repeating:
            ((min + max) > 0) ?
            GridItem(
                .adaptive(
                    minimum: min,
                    maximum: max,
                ),
                spacing: spacing
            ) :
            GridItem(.flexible(), spacing: spacing),
            count: ((min + max) > 0) ? 1 : columns
        )

        let anim = StyleResolver.animation(definition.style?.animation)
        let ids = rendered.map(\.id)

        LazyVGrid(columns: gridItems, spacing: spacing) {
            ForEach(rendered) { item in
                renderedItemContent(item)
            }
        }
        .melodyStyle(definition.style)
        .maybeAnimate(anim, value: ids)
    }

    @ViewBuilder
    private func renderedItemContent(_ item: RenderedListItem) -> some View {
        ForEach(Array(item.components.enumerated()), id: \.offset) { _, comp in
            ComponentRenderer(components: [comp])
                .id(componentFingerprint(comp))
        }
    }

    /// Produces a lightweight hash of the component's key visual properties so SwiftUI
    /// detects changes in render-function-produced components (where style values are
    /// pre-resolved rather than Lua expressions).
    private func componentFingerprint(_ def: ComponentDefinition) -> Int {
        var hasher = Hasher()
        hasher.combine(def.id)
        hasher.combine(def.text)
        hasher.combine(def.label)
        hasher.combine(def.visible)
        hasher.combine(def.src)
        hasher.combine(def.systemImage)
        hasher.combine(def.style?.backgroundColor)
        hasher.combine(def.style?.color)
        hasher.combine(def.style?.borderColor)
        hasher.combine(def.style?.opacity)
        hasher.combine(def.style?.fontWeight)
        hasher.combine(def.children?.hashValue)
        return hasher.finalize()
    }

    /// Renders dynamic items via `items` + `render` for container components (form, section).
    @ViewBuilder
    private func renderDynamicItems(_ definition: ComponentDefinition) -> some View {
        if definition.render != nil {
            let rendered = preResolveItems(definition)
            ForEach(rendered) { item in
                renderedItemContent(item)
            }
        }
    }

    private func executeLua(_ script: String?) {
        guard let script = script, let vm = luaVM else { return }
        setupScope()
        let prefix = resolver.propsPrefix()
        vm.executeAsync(prefix + script) { result in
            if case .failure(let error) = result {
                print("[Melody] Lua error: \(error.localizedDescription)")
            }
        }
    }

    private func resolveRenderFunction(item: LuaValue, index: Int, script: String) -> [ComponentDefinition] {
        guard let vm = luaVM else { return [] }
        vm.setStateRaw(key: "_current_item", value: item)
        vm.setStateRaw(key: "_current_index", value: .number(Double(index)))

        do {
            let result = try vm.execute("""
                local item = state._current_item
                local index = state._current_index
                \(script)
            """)

            if let table = result.tableValue {
                return [componentFromTable(table)]
            }
        } catch {
            print("[Melody] Render function error: \(error.localizedDescription)")
            print("[Melody] Script: \(script)")
        }
        return []
    }

    private func componentFromTable(_ table: [String: LuaValue]) -> ComponentDefinition {
        var def = ComponentDefinition(
            component: table["component"]?.stringValue ?? "Text",
            id: table["id"]?.stringValue,
        )
        def.text = table["text"]?.stringValue.map { Value<String>.from($0) }
        def.label = table["label"]?.stringValue.map { Value<String>.from($0) }
        def.onTap = table["onTap"]?.stringValue
        def.src = table["src"]?.stringValue.map { Value<String>.from($0) }
        def.systemImage = table["systemImage"]?.stringValue.map { Value<String>.from($0) }
        def.direction = table["direction"]?.stringValue.map { .literal(DirectionAxis(rawValue: $0)) }
        def.visible = table["visible"]?.boolValue.map { .literal($0) }
        def.placeholder = table["placeholder"]?.stringValue.map { Value<String>.from($0) }
        def.value = table["value"]?.stringValue.map { Value<String>.from($0) }
        def.onChanged = table["onChanged"]?.stringValue
        def.onHover = table["onHover"]?.stringValue
        def.items = table["items"]?.stringValue
        def.render = table["render"]?.stringValue
        def.usesSharedObjectTransition = table["usesSharedObjectTransition"]?.boolValue
        def.inputType = table["inputType"]?.stringValue
        def.stateKey = table["stateKey"]?.stringValue
        def.min = table["min"]?.numberValue
        def.max = table["max"]?.numberValue
        def.step = table["step"]?.numberValue
        def.url = table["url"]?.stringValue.map { Value<String>.from($0) }
        def.pickerStyle = table["pickerStyle"]?.stringValue
        def.datePickerStyle = table["datePickerStyle"]?.stringValue
        def.displayedComponents = table["displayedComponents"]?.stringValue
        def.columns = luaValueToNumericValue(table["columns"])
        def.maxColumnWidth = luaValueToNumericValue(table["maxColumnWidth"])
        def.minColumnWidth = luaValueToNumericValue(table["minColumnWidth"])
        def.footer = table["footer"]?.stringValue.map { Value<String>.from($0) }
        def.formStyle = table["formStyle"]?.stringValue
        def.legendPosition = table["legendPosition"]?.stringValue
        def.hideXAxis = table["hideXAxis"]?.boolValue
        def.hideYAxis = table["hideYAxis"]?.boolValue
        def.shouldGrowToFitParent = table["shouldGrowToFitParent"]?.boolValue
        def.transition = table["transition"]?.stringValue.map { Value<String>.from($0) }

        if let marksValue = table["marks"] {
            if case .array(let arr) = marksValue {
                def.marks = arr.compactMap { markValue in
                    guard let t = markValue.tableValue,
                          let type = t["type"]?.stringValue else { return nil }
                    return MarkDefinition(
                        type: type,
                        xKey: t["xKey"]?.stringValue,
                        yKey: t["yKey"]?.stringValue,
                        groupKey: t["groupKey"]?.stringValue,
                        angleKey: t["angleKey"]?.stringValue,
                        innerRadius: t["innerRadius"]?.numberValue,
                        angularInset: t["angularInset"]?.numberValue,
                        xValue: t["xValue"]?.stringValue,
                        yValue: t["yValue"]?.numberValue,
                        label: t["label"]?.stringValue,
                        xStartKey: t["xStartKey"]?.stringValue,
                        xEndKey: t["xEndKey"]?.stringValue,
                        yStartKey: t["yStartKey"]?.stringValue,
                        yEndKey: t["yEndKey"]?.stringValue,
                        interpolation: t["interpolation"]?.stringValue,
                        lineWidth: t["lineWidth"]?.numberValue,
                        cornerRadius: t["cornerRadius"]?.numberValue,
                        symbolSize: t["symbolSize"]?.numberValue,
                        stacking: t["stacking"]?.stringValue,
                        color: t["color"]?.stringValue
                    )
                }
            }
        }

        if let colorsValue = table["colors"] {
            if case .array(let arr) = colorsValue {
                def.colors = arr.compactMap { $0.stringValue }
            }
        }

        if let optionsValue = table["options"] {
            if case .array(let arr) = optionsValue {
                let parsed = arr.compactMap { item -> OptionDefinition? in
                    guard let t = item.tableValue,
                          let label = t["label"]?.stringValue,
                          let value = t["value"]?.stringValue else { return nil }
                    return OptionDefinition(label: label, value: value)
                }
                def.options = .static(parsed)
            } else if let expr = optionsValue.stringValue {
                def.options = .expression(expr)
            }
        }

        if let propsTable = table["props"]?.tableValue {
            def.props = propsTable.compactMapValues { value -> Value<String>? in
                switch value {
                case .string(let s): return Value<String>.from(s)
                case .number(let n):
                    if n == n.rounded() && n < 1e15 { return .literal(String(Int(n))) }
                    return .literal(String(n))
                case .bool(let b): return .literal(b ? "true" : "false")
                default: return nil
                }
            }
        }

        if let bindingsValue = table["bindings"] {
            if case .array(let arr) = bindingsValue {
                def.bindings = arr.compactMap { $0.stringValue }
            }
        }

        if let menuValue = table["contextMenu"] {
            if case .array(let items) = menuValue {
                def.contextMenu = items.compactMap { item in
                    guard let t = item.tableValue else { return nil }
                    let isSection = t["section"]?.boolValue ?? false
                    let label = t["label"]?.stringValue ?? ""
                    if !isSection && label.isEmpty { return nil }
                    return ContextMenuItem(
                        label: label,
                        systemImage: t["systemImage"]?.stringValue,
                        style: t["style"]?.stringValue,
                        onTap: t["onTap"]?.stringValue,
                        section: isSection ? true : nil
                    )
                }
            }
        }

        if let lsTable = table["localState"]?.tableValue {
            def.localState = lsTable.compactMapValues { luaValueToStateValue($0) }
        }

        if let styleTable = table["style"]?.tableValue {
            def.style = styleFromTable(styleTable)
        }

        // Support lineLimit at the component root level (merged into style)
        if let lineLimit = table["lineLimit"]?.numberValue {
            if def.style == nil { def.style = ComponentStyle() }
            if def.style?.lineLimit == nil {
                def.style?.lineLimit = .literal(Int(lineLimit))
            }
        }

        if let bgTable = table["background"]?.tableValue {
            def.background = backgroundFromTable(bgTable)
        }

        if let childrenArray = table["children"] {
            if case .array(let children) = childrenArray {
                def.children = children.compactMap { child in
                    if let childTable = child.tableValue {
                        return componentFromTable(childTable)
                    }
                    return nil
                }
            }
        }

        return def
    }

    /// Converts a Lua value to Value<Double> — numbers become .literal, strings go through Value.from().
    private func luaValueToNumericValue(_ luaValue: LuaValue?) -> Value<Double>? {
        guard let luaValue else { return nil }
        if let n = luaValue.numberValue { return .literal(n) }
        if let s = luaValue.stringValue { return Value<Double>.from(s) }
        return nil
    }

    private func luaValueToStateValue(_ lv: LuaValue) -> StateValue? {
        switch lv {
        case .string(let s): return .string(s)
        case .number(let n): return n == n.rounded() ? .int(Int(n)) : .double(n)
        case .bool(let b): return .bool(b)
        case .nil: return .null
        case .array(let a): return .array(a.compactMap { luaValueToStateValue($0) })
        case .table(let t): return .dictionary(t.compactMapValues { luaValueToStateValue($0) })
        }
    }

    private func backgroundFromTable(_ table: [String: LuaValue]) -> ComponentRef {
        ComponentRef(componentFromTable(table))
    }

    private func styleFromTable(_ table: [String: LuaValue]) -> ComponentStyle {
        var style = ComponentStyle()

        style.fontWeight = table["fontWeight"]?.stringValue
        style.fontDesign = table["fontDesign"]?.stringValue
        style.color = table["color"]?.stringValue.map { Value<String>.from($0) }
        style.backgroundColor = table["backgroundColor"]?.stringValue.map { Value<String>.from($0) }
        style.borderColor = table["borderColor"]?.stringValue.map { Value<String>.from($0) }
        style.alignment = table["alignment"]?.stringValue.map { .literal(ViewAlignment(rawValue: $0)) }
        style.animation = table["animation"]?.stringValue
        style.contentMode = table["contentMode"]?.stringValue
        style.overflow = table["overflow"]?.stringValue
        style.lineLimit = table["lineLimit"]?.numberValue.map { .literal(Int($0)) }

        style.fontSize = luaValueToNumericValue(table["fontSize"])
        style.padding = luaValueToNumericValue(table["padding"])
        style.paddingTop = luaValueToNumericValue(table["paddingTop"])
        style.paddingBottom = luaValueToNumericValue(table["paddingBottom"])
        style.paddingLeft = luaValueToNumericValue(table["paddingLeft"])
        style.paddingRight = luaValueToNumericValue(table["paddingRight"])
        style.paddingHorizontal = luaValueToNumericValue(table["paddingHorizontal"])
        style.paddingVertical = luaValueToNumericValue(table["paddingVertical"])
        style.borderRadius = luaValueToNumericValue(table["borderRadius"])
        style.cornerRadius = luaValueToNumericValue(table["cornerRadius"])
        style.borderWidth = luaValueToNumericValue(table["borderWidth"])
        style.width = luaValueToNumericValue(table["width"])
        style.height = luaValueToNumericValue(table["height"])
        style.minWidth = luaValueToNumericValue(table["minWidth"])
        style.minHeight = luaValueToNumericValue(table["minHeight"])
        style.maxWidth = luaValueToNumericValue(table["maxWidth"])
        style.maxHeight = luaValueToNumericValue(table["maxHeight"])
        style.spacing = luaValueToNumericValue(table["spacing"])
        style.opacity = luaValueToNumericValue(table["opacity"])
        style.margin = luaValueToNumericValue(table["margin"])
        style.marginTop = luaValueToNumericValue(table["marginTop"])
        style.marginBottom = luaValueToNumericValue(table["marginBottom"])
        style.marginLeft = luaValueToNumericValue(table["marginLeft"])
        style.marginRight = luaValueToNumericValue(table["marginRight"])
        style.marginHorizontal = luaValueToNumericValue(table["marginHorizontal"])
        style.marginVertical = luaValueToNumericValue(table["marginVertical"])
        style.scale = luaValueToNumericValue(table["scale"])
        style.rotation = luaValueToNumericValue(table["rotation"])
        style.aspectRatio = luaValueToNumericValue(table["aspectRatio"])
        style.layoutPriority = luaValueToNumericValue(table["layoutPriority"])

        if let shadowTable = table["shadow"]?.tableValue {
            style.shadow = ShadowStyle(
                x: shadowTable["x"]?.numberValue,
                y: shadowTable["y"]?.numberValue,
                blur: shadowTable["blur"]?.numberValue,
                color: shadowTable["color"]?.stringValue
            )
        }
        return style
    }
}

// MARK: - Conditional Animation

extension View {
    @ViewBuilder
    func maybeAnimate(_ animation: Animation?, value: some Equatable) -> some View {
        if let animation {
            self.animation(animation, value: value)
        } else {
            self
        }
    }
}

// MARK: - Background Component Modifier

extension View {
    @ViewBuilder
    func backgroundComponent(_ bg: ComponentRef?, cornerRadius: Double = 0) -> some View {
        if let bg {
            self.background {
                ComponentRenderer(components: [bg.wrapped])
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
        }
    }
}
