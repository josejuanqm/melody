import SwiftUI
import Core

/// Renders a segmented, wheel, or menu picker bound to a screen state key.
struct MelodyPicker: View {
    let definition: ComponentDefinition
    var resolvedOptions: [OptionDefinition] = []
    var onChanged: ((String) -> Void)? = nil

    @Environment(\.screenState) private var screenState
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        picker
            .melodyStyle(definition.style)
            .onChange(of: binding.wrappedValue) { _, newValue in
                onChanged?(newValue)
            }
    }

    @ViewBuilder
    private var picker: some View {
        let base = Picker(resolvedLabel, selection: binding) {
            ForEach(resolvedOptions, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        switch PickerVariant(definition.pickerStyle) {
        case .segmented:
            base.pickerStyle(.segmented)
        #if canImport(UIKit) && !os(tvOS)
        case .wheel:
            base.pickerStyle(.wheel)
        #endif
        default:
            base.pickerStyle(.menu)
        }
    }

    private var resolvedLabel: String {
        definition.label.resolved ?? ""
    }

    private var binding: Binding<String> {
        guard let key = definition.stateKey else {
            return .constant("")
        }
        return Binding(
            get: { screenState.get(key: key).stringValue ?? "" },
            set: { screenState.set(key: key, value: .string($0)) }
        )
    }
}
