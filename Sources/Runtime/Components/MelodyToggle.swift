import SwiftUI
import Core

/// Renders a toggle switch bound to a screen state key.
struct MelodyToggle: View {
    let definition: ComponentDefinition
    var onChanged: (() -> Void)? = nil

    @Environment(\.screenState) private var screenState
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        Toggle(resolvedLabel, isOn: binding)
            .tint(tintColor)
            .onChange(of: binding.wrappedValue) { _, _ in
                onChanged?()
            }
    }

    private var resolvedLabel: String {
        definition.label.resolved ?? ""
    }

    private var binding: Binding<Bool> {
        guard let key = definition.stateKey else {
            return .constant(false)
        }
        return Binding(
            get: { screenState.get(key: key).boolValue ?? false },
            set: { screenState.set(key: key, value: .bool($0)) }
        )
    }

    private var tintColor: Color? {
        guard let value = definition.style?.color.resolved else { return nil }
        return Color(hex: StyleResolver.colorHex(value, themeColors: themeColors))
    }
}
