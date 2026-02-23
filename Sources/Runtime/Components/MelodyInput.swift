import SwiftUI
import Core

/// Renders a text input field supporting plain, secure, and textarea variants.
struct MelodyInput: View {
    let definition: ComponentDefinition
    let resolvedLabel: String?
    let resolvedValue: String
    let onChanged: (String) -> Void
    var onSubmit: (() -> Void)? = nil

    @State private var text: String = ""

    private var inputVariant: InputVariant {
        InputVariant(definition.inputType)
    }

    private var isSecure: Bool {
        inputVariant == .password || inputVariant == .secure
    }

    private var isTextarea: Bool {
        inputVariant == .textarea
    }

    private var placeholder: String {
        if let resolvedLabel, !resolvedLabel.isEmpty {
            return resolvedLabel
        }

        return definition.placeholder.resolved ?? ""
    }

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else if isTextarea {
                #if os(tvOS)
                textField
                #else
                textArea
                #endif
            } else {
                textField
            }
        }
        .font(.system(size: CGFloat(definition.style?.fontSize.resolved ?? 16)))
        #if os(tvOS)
        .melodyStyle(nil)
        #else
        .melodyStyle(definition.style)
        #endif
        .onAppear {
            text = resolvedValue
        }
        .onChange(of: resolvedValue) { _, newValue in
            if newValue != text {
                text = newValue
            }
        }
        .onChange(of: text) { _, newValue in
            onChanged(newValue)
        }
        .onSubmit {
            onSubmit?()
        }
        .textFieldStyle(.plain)
    }

#if os(tvOS)
#else
    private var textArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(definition.style?.minHeight.resolved ?? 120))
            if text.isEmpty, let placeholder = definition.placeholder.resolved {
                Text(placeholder)
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
    }
#endif

    private var textField: some View {
        let field = TextField(placeholder, text: $text)
        #if canImport(UIKit)
        return field
            .keyboardType(keyboardType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(disableAutocorrect)
            .textContentType(contentType)
            .submitLabel(submitLabel)
        #else
        return field
        #endif
    }

    #if canImport(UIKit)
    private var keyboardType: UIKeyboardType {
        switch inputVariant {
        case .url: return .URL
        case .email: return .emailAddress
        case .number: return .numberPad
        case .phone: return .phonePad
        default: return .default
        }
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch inputVariant {
        case .url, .email: return .never
        default: return .sentences
        }
    }

    private var disableAutocorrect: Bool {
        switch inputVariant {
        case .url, .email, .password, .secure: return true
        default: return false
        }
    }

    private var contentType: UITextContentType? {
        switch inputVariant {
        case .url: return .URL
        case .email: return .emailAddress
        case .password, .secure: return .password
        default: return nil
        }
    }

    private var submitLabel: SubmitLabel {
        switch inputVariant {
        case .search: return .search
        default: return .done
        }
    }
    #endif
}
