import SwiftUI
import Core

#if os(tvOS)
#else
/// Renders a date picker bound to a screen state key, storing ISO 8601 strings.
struct MelodyDatePicker: View {
    let definition: ComponentDefinition
    var onChanged: (() -> Void)? = nil

    @Environment(\.screenState) private var screenState

    var body: some View {
        datePicker
            .melodyStyle(definition.style)
            .onChange(of: binding.wrappedValue) { _, _ in
                onChanged?()
            }
    }

    @ViewBuilder
    private var datePicker: some View {
        let base = DatePicker(
            resolvedLabel,
            selection: binding,
            displayedComponents: dateComponents
        )
        switch DatePickerVariant(definition.datePickerStyle) {
        case .graphical:
            base.datePickerStyle(.graphical)
        #if canImport(UIKit)
        case .wheel:
            base.datePickerStyle(.wheel)
        #endif
        default:
            base.datePickerStyle(.compact)
        }
    }

    private var resolvedLabel: String {
        definition.label.resolved ?? ""
    }

    private var binding: Binding<Date> {
        guard let key = definition.stateKey else {
            return .constant(Date())
        }
        return Binding(
            get: {
                if let str = screenState.get(key: key).stringValue {
                    return parseISO8601(str) ?? Date()
                }
                return Date()
            },
            set: { value in
                screenState.set(key: key, value: .string(formatISO8601(value)))
            }
        )
    }

    private var dateComponents: DatePickerComponents {
        switch DateDisplayComponents(definition.displayedComponents) {
        case .time: return [.hourAndMinute]
        case .datetime: return [.date, .hourAndMinute]
        case .date: return [.date]
        }
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
#endif
