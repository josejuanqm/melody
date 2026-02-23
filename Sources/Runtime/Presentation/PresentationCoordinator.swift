import SwiftUI
import Observation
import Core

// MARK: - Alert Models

/// Configuration for a single button inside a ``MelodyAlertConfig``.
struct MelodyAlertButton {
    let title: String
    let role: ButtonRole?
    let onTap: String?

    init(title: String, role: ButtonRole? = nil, onTap: String? = nil) {
        self.title = title
        self.role = role
        self.onTap = onTap
    }
}

/// Parsed alert parameters (title, message, buttons) produced by `melody.alert()` calls.
struct MelodyAlertConfig {
    let title: String
    let message: String?
    let buttons: [MelodyAlertButton]

    static func from(args: [LuaValue]) -> MelodyAlertConfig {
        let title = args.first?.stringValue ?? ""
        let message = args.count >= 2 ? args[1].stringValue : nil

        var buttons: [MelodyAlertButton] = []
        if args.count >= 3, case .array(let buttonArray) = args[2] {
            for entry in buttonArray {
                if let dict = entry.tableValue {
                    let btnTitle = dict["title"]?.stringValue ?? dict["text"]?.stringValue ?? "OK"
                    let styleStr = dict["style"]?.stringValue
                    let onTap = dict["onTap"]?.stringValue ?? dict["action"]?.stringValue
                    let role: ButtonRole? = switch AlertButtonVariant(styleStr) {
                        case .destructive: .destructive
                        case .cancel: .cancel
                        case .default: nil
                    }
                    buttons.append(MelodyAlertButton(title: btnTitle, role: role, onTap: onTap))
                }
            }
        }
        if buttons.isEmpty {
            buttons = [MelodyAlertButton(title: "OK")]
        }

        return MelodyAlertConfig(title: title, message: message, buttons: buttons)
    }
}

// MARK: - Sheet Models

/// Parsed sheet parameters (path, detent, style) produced by `melody.sheet()` calls.
struct MelodySheetConfig {
    let screenPath: String
    let detent: String?
    let style: String?
    let showsToolbar: Bool?
    let sourceId: String?
}

// MARK: - Presentation Coordinator

/// Observable state holder for the currently displayed alert and sheet on a screen.
@Observable
final class PresentationCoordinator {
    var alert: MelodyAlertConfig?
    var sheet: MelodySheetConfig?
    var namespace: Namespace.ID?
}

// MARK: - Dismiss Environment Key

private struct MelodyDismissKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var melodyDismiss: (() -> Void)? {
        get { self[MelodyDismissKey.self] }
        set { self[MelodyDismissKey.self] = newValue }
    }
}
