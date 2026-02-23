import SwiftUI
import Core

// MARK: - Title Display Mode Modifier

#if !os(macOS)
struct TitleDisplayModeModifier: ViewModifier {
    let mode: String?

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
        #else
        switch TitleDisplayModeVariant(mode) {
        case .inline:
            content.navigationBarTitleDisplayMode(.inline)
        case .large:
            content.navigationBarTitleDisplayMode(.large)
        case .automatic:
            content
        }
        #endif
    }
}
#endif

// MARK: - Toolbar String Resolution

func resolveToolbarString(_ value: Value<String>?, vm: LuaVM) -> String? {
    guard let value else { return nil }
    switch value {
    case .literal(let s): return s
    case .expression(let expr):
        do {
            let result = try vm.evaluate(expr)
            switch result {
            case .string(let s): return s
            case .nil: return nil
            default: return expr
            }
        } catch {
            return expr
        }
    }
}

func resolveToolbarString(_ value: String?, vm: LuaVM) -> String? {
    guard let value else { return nil }
    if let expr = Value<String>.extractExpression(value) {
        do {
            let result = try vm.evaluate(expr)
            switch result {
            case .string(let s): return s
            case .nil: return nil
            default: return value
            }
        } catch {
            return value
        }
    }
    return value
}
