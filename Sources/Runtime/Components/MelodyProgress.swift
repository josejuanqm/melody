import SwiftUI
import Core

/// Renders a determinate or indeterminate progress indicator with an optional label.
struct MelodyProgress: View {
    let definition: ComponentDefinition
    let resolvedValue: String?
    let resolvedLabel: String?

    var body: some View {
        Group {
            if let value = progressValue {
                if let label = resolvedLabel, !label.isEmpty {
                    ProgressView(label, value: value)
                } else {
                    ProgressView(value: value)
                }
            } else {
                if let label = resolvedLabel, !label.isEmpty {
                    ProgressView(label)
                } else {
                    ProgressView()
                }
            }
        }
        .melodyStyle(definition.style)
    }

    private var progressValue: Double? {
        guard let str = resolvedValue, !str.isEmpty else { return nil }
        return Double(str)
    }
}
