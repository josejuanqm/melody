import SwiftUI
import Core

struct TitleMenuModifier: ViewModifier {
    let items: [ComponentDefinition]?
    let builder: String?
    let luaVM: LuaVM?

    func body(content: Content) -> some View {
        if let vm = luaVM, let builder, !builder.isEmpty {
            let dynamicItems = evaluateBuilder(builder, vm: vm)
            if !dynamicItems.isEmpty {
                content.toolbarTitleMenu {
                    ForEach(Array(dynamicItems.enumerated()), id: \.offset) { _, item in
                        dynamicMenuButton(item, vm: vm)
                    }
                }
            } else {
                content
            }
        } else if let items, !items.isEmpty, let vm = luaVM {
            content.toolbarTitleMenu {
                ForEach(Array(items.enumerated()), id: \.offset) { _, child in
                    staticMenuButton(child, vm: vm)
                }
            }
        } else {
            content
        }
    }

    private func evaluateBuilder(_ script: String, vm: LuaVM) -> [[String: LuaValue]] {
        do {
            let result = try vm.execute(script)
            if case .array(let arr) = result {
                return arr.compactMap { $0.tableValue }
            }
        } catch {
            print("[Melody] Title menu builder error: \(error.localizedDescription)")
        }
        return []
    }

    @ViewBuilder
    private func dynamicMenuButton(_ item: [String: LuaValue], vm: LuaVM) -> some View {
        let label = item["label"]?.stringValue ?? ""
        let systemImage = resolveToolbarString(item["systemImage"]?.stringValue, vm: vm)
        let onTap = item["onTap"]?.stringValue

        Button {
            if let script = onTap {
                vm.executeAsync(script) { result in
                    if case .failure(let error) = result {
                        print("[Melody] Title menu error: \(error.localizedDescription)")
                    }
                }
            }
        } label: {
            if let systemImage {
                Label(label, systemImage: systemImage)
            } else {
                Text(label)
            }
        }
    }

    @ViewBuilder
    private func staticMenuButton(_ child: ComponentDefinition, vm: LuaVM) -> some View {
        let resolvedImage = resolveToolbarString(child.systemImage, vm: vm)
        Button {
            if let script = child.onTap {
                vm.executeAsync(script) { result in
                    if case .failure(let error) = result {
                        print("[Melody] Title menu error: \(error.localizedDescription)")
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
}
