import SwiftUI
import Core

// MARK: - Presentation Views

extension ScreenView {

    @ViewBuilder
    func sheetContent(config: MelodySheetConfig) -> some View {
        if let screenDef = navigator.screen(for: config.screenPath) {
            NavigationStack {
#if os(macOS)
                if #available(macOS 15.0, *) {
                    ScreenView(definition: screenDef, http: http, actualPath: config.screenPath)
                        .environment(\.melodyDismiss, { presentation.sheet = nil })
                        .toolbarVisibility(config.showsToolbar ?? true ? .automatic : .hidden, for: .automatic)
                } else {
                    ScreenView(definition: screenDef, http: http, actualPath: config.screenPath)
                        .environment(\.melodyDismiss, { presentation.sheet = nil })
                }
#elseif os(iOS)
                if #available(iOS 18.0, *) {
                    ScreenView(definition: screenDef, http: http, actualPath: config.screenPath)
                        .environment(\.melodyDismiss, { presentation.sheet = nil })
                        .toolbarVisibility(config.showsToolbar ?? true ? .automatic : .hidden, for: .automatic)
                } else {
                    ScreenView(definition: screenDef, http: http, actualPath: config.screenPath)
                        .environment(\.melodyDismiss, { presentation.sheet = nil })
                }
#endif
            }
            .presentationDetents(SheetDetent(config.detent) == .medium ? [.medium, .large] : [.large])
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Screen not found: \(config.screenPath)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)

            Text("Error")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Screen: \(definition.id)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.red)
    }
}

// MARK: - Screen Presentation Modifier

struct ScreenPresentationModifier: ViewModifier {
    @Bindable var presentation: PresentationCoordinator
    let luaVM: LuaVM?
    let sheetContentBuilder: (MelodySheetConfig) -> AnyView
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .alert(
                presentation.alert?.title ?? "",
                isPresented: Binding(
                    get: { presentation.alert != nil },
                    set: { if !$0 { presentation.alert = nil } }
                ),
                presenting: presentation.alert
            ) { config in
                ForEach(Array(config.buttons.enumerated()), id: \.offset) { _, button in
                    Button(role: button.role) {
                        if let script = button.onTap, let vm = luaVM {
                            vm.executeAsync(script) { result in
                                if case .failure(let error) = result {
                                    print("[Melody] Alert button error: \(error.localizedDescription)")
                                }
                            }
                        }
                    } label: {
                        Text(button.title)
                    }
                }
            } message: { config in
                if let message = config.message {
                    Text(message)
                }
            }
            #if os(macOS)
            .sheet(isPresented: Binding(
                get: { presentation.sheet != nil },
                set: { if !$0 { presentation.sheet = nil } }
            )) {
                if let config = presentation.sheet {
                    sheetContentBuilder(config)
                }
            }
            #else
            .sheet(isPresented: Binding(
                get: { presentation.sheet != nil && SheetStyle(presentation.sheet?.style) != .fullscreen },
                set: { if !$0 { presentation.sheet = nil } }
            )) {
                if let config = presentation.sheet {
                    if #available(iOS 18.0, *) {
                        sheetContentBuilder(config)
                            .modifier(
                                NavigationTransitionModifier(
                                    shouldApplyTransition: config.sourceId != nil,
                                    navigationType: .zoom(sourceID: config.sourceId, in: namespace)
                                )
                            )
                    } else {
                        sheetContentBuilder(config)
                    }
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { presentation.sheet != nil && SheetStyle(presentation.sheet?.style) == .fullscreen },
                set: { if !$0 { presentation.sheet = nil } }
            )) {
                if let config = presentation.sheet {
                    if #available(iOS 18.0, *) {
                        sheetContentBuilder(config)
                            .modifier(
                                NavigationTransitionModifier(
                                    shouldApplyTransition: config.sourceId != nil,
                                    navigationType: .zoom(sourceID: config.sourceId, in: namespace)
                                )
                            )
                    } else {
                        sheetContentBuilder(config)
                    }
                }
            }
            #endif
    }
}
