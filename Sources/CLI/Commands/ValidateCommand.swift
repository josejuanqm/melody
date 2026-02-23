import ArgumentParser
import Foundation
import Core

/// Validates a Melody app definition for schema correctness and reports errors or warnings.
struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a Melody app definition"
    )

    @Option(name: .shortAndLong, help: "Path to app.yaml file or project directory")
    var file: String = "app.yaml"

    func run() throws {
        let path = resolvePath(file)
        print("Validating \(path)...")

        let parser = AppParser()
        let projectDir = AppParser.isDirectory(path) ? path : (path as NSString).deletingLastPathComponent
        let app: AppDefinition

        do {
            app = try parser.parseDirectory(at: projectDir)
        } catch {
            printError("Failed to parse YAML: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        var errors: [String] = []
        var warnings: [String] = []

        if app.app.name.isEmpty {
            errors.append("app.name is required")
        }

        if app.screens.isEmpty {
            errors.append("At least one screen is required")
        }

        var seenPaths = Set<String>()
        var seenIds = Set<String>()

        for screen in app.screens {
            if seenIds.contains(screen.id) {
                errors.append("Duplicate screen id: '\(screen.id)'")
            }
            seenIds.insert(screen.id)

            if seenPaths.contains(screen.path) {
                errors.append("Duplicate screen path: '\(screen.path)'")
            }
            seenPaths.insert(screen.path)

            if screen.tabs != nil {
                for tab in screen.tabs! {
                    if tab.id.isEmpty { errors.append("Screen '\(screen.id)': tab missing 'id'") }
                    if tab.title.isEmpty { errors.append("Screen '\(screen.id)': tab missing 'title'") }
                    if tab.icon.isEmpty { errors.append("Screen '\(screen.id)': tab missing 'icon'") }
                    if tab.screen.isEmpty { errors.append("Screen '\(screen.id)': tab missing 'screen'") }
                }
            } else if let body = screen.body {
                if body.isEmpty {
                    warnings.append("Screen '\(screen.id)' has an empty body")
                }
                for component in body {
                    validateComponent(component, screenId: screen.id, errors: &errors, warnings: &warnings)
                }
            } else {
                errors.append("Screen '\(screen.id)' has neither 'body' nor 'tabs'")
            }
        }

        if !seenPaths.contains("/") {
            warnings.append("No screen with path '/' found — first screen will be used as root")
        }

        if errors.isEmpty && warnings.isEmpty {
            print("✓ Validation passed — \(app.screens.count) screen(s), app '\(app.app.name)'")
        } else {
            for warning in warnings {
                print("⚠ \(warning)")
            }
            for error in errors {
                printError(error)
            }
            if !errors.isEmpty {
                print("\n✗ Validation failed with \(errors.count) error(s)")
                throw ExitCode.failure
            } else {
                print("\n✓ Validation passed with \(warnings.count) warning(s)")
            }
        }
    }

    private func validateComponent(_ component: ComponentDefinition, screenId: String, errors: inout [String], warnings: inout [String]) {
        let validComponents = [
            "text", "button", "stack", "image", "input", "list", "grid", "spacer", "screen",
            "activity", "toggle", "divider", "picker", "slider", "progress", "stepper",
            "datepicker", "menu", "link", "disclosure", "state_provider",
            "form", "section", "chart"
        ]

        if !component.component.hasPrefix("./") && !component.component.hasPrefix("/") {
            if !validComponents.contains(component.component.lowercased()) {
                warnings.append("Screen '\(screenId)': Unknown component '\(component.component)'")
            }
        }

        switch component.component.lowercased() {
        case "button":
            if component.label == nil {
                warnings.append("Screen '\(screenId)': Button missing 'label'")
            }
        case "list", "grid":
            if component.items == nil {
                errors.append("Screen '\(screenId)': \(component.component) requires 'items'")
            }
            if component.render == nil {
                errors.append("Screen '\(screenId)': \(component.component) requires 'render'")
            }
        case "toggle", "slider", "stepper", "datepicker":
            if component.stateKey == nil {
                errors.append("Screen '\(screenId)': \(component.component) requires 'stateKey'")
            }
        case "picker":
            if component.stateKey == nil {
                errors.append("Screen '\(screenId)': Picker requires 'stateKey'")
            }
            if component.options == nil || component.options?.isEmpty == true {
                warnings.append("Screen '\(screenId)': Picker has no 'options' (may be dynamic)")
            }
        case "link":
            if component.url == nil {
                errors.append("Screen '\(screenId)': Link requires 'url'")
            }
        case "chart":
            if component.items == nil {
                errors.append("Screen '\(screenId)': Chart requires 'items'")
            }
            if let marks = component.marks, !marks.isEmpty {
                for mark in marks {
                    let type = mark.type.lowercased()
                    switch type {
                    case "bar", "line", "point", "area":
                        if mark.xKey == nil {
                            errors.append("Screen '\(screenId)': Chart \(type) mark requires 'xKey'")
                        }
                        if mark.yKey == nil {
                            errors.append("Screen '\(screenId)': Chart \(type) mark requires 'yKey'")
                        }
                    case "sector":
                        if mark.angleKey == nil {
                            errors.append("Screen '\(screenId)': Chart sector mark requires 'angleKey'")
                        }
                    case "rule":
                        if mark.xValue == nil && mark.yValue == nil {
                            errors.append("Screen '\(screenId)': Chart rule mark requires 'xValue' or 'yValue'")
                        }
                    case "rectangle":
                        break
                    default:
                        warnings.append("Screen '\(screenId)': Unknown chart mark type '\(mark.type)'")
                    }
                }
            } else {
                errors.append("Screen '\(screenId)': Chart requires 'marks'")
            }
        default:
            break
        }

        if let children = component.children {
            for child in children {
                validateComponent(child, screenId: screenId, errors: &errors, warnings: &warnings)
            }
        }
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        return (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(path)
    }

    private func printError(_ message: String) {
        print("✗ \(message)")
    }
}
