import SwiftUI
import Core

#if os(tvOS)
#else
/// Renders a continuous slider bound to a screen state key with configurable range.
struct MelodySlider: View {
    let definition: ComponentDefinition
    var onChanged: (() -> Void)? = nil

    @Environment(\.screenState) private var screenState

    var body: some View {
        Slider(
            value: binding,
            in: minValue...maxValue,
            step: stepValue
        )
        .melodyStyle(definition.style)
        .onChange(of: binding.wrappedValue) { _, _ in
            onChanged?()
        }
    }

    private var binding: Binding<Double> {
        guard let key = definition.stateKey else {
            return .constant(0)
        }
        return Binding(
            get: { screenState.get(key: key).numberValue ?? 0 },
            set: { screenState.set(key: key, value: .number($0)) }
        )
    }

    private var minValue: Double { definition.min ?? 0 }
    private var maxValue: Double { definition.max ?? 1 }
    private var stepValue: Double { definition.step ?? 0.1 }
}
#endif
