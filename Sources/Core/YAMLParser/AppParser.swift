import Foundation
import Yams

/// Parses YAML app definitions into typed schema models
public struct AppParser {

    public init() {}

    /// Parse a YAML string into an AppDefinition
    public func parse(_ yaml: String) throws -> AppDefinition {
        let decoder = YAMLDecoder()
        return try decoder.decode(AppDefinition.self, from: yaml)
    }

    /// Parse a YAML file at the given path
    public func parseFile(at path: String) throws -> AppDefinition {
        let url = URL(fileURLWithPath: path)
        let yaml = try String(contentsOf: url, encoding: .utf8)
        return try parse(yaml)
    }

    /// Parse a directory containing app.yaml and screen files in any subdirectory.
    ///
    /// Structure:
    /// ```
    /// myapp/
    ///   app.yaml              — app config, components, and optionally inline screens
    ///   screens/
    ///     home.yaml           — single ScreenDefinition per file
    ///     settings.yaml
    ///   screens/auth/
    ///     login.yaml          — nested subdirectories also scanned
    /// ```
    public func parseDirectory(at dirPath: String) throws -> AppDefinition {
        let fm = FileManager.default
        let appFile = (dirPath as NSString).appendingPathComponent("app.yaml")

        guard fm.fileExists(atPath: appFile) else {
            throw ParserError.missingAppYaml(directory: dirPath)
        }

        var app = try parseFile(at: appFile)

        let decoder = YAMLDecoder()

        let componentFiles = Self.findComponentFiles(in: dirPath)
        for filePath in componentFiles {
            let yaml = try String(contentsOfFile: filePath, encoding: .utf8)
            let component = try decoder.decode(CustomComponentDefinition.self, from: yaml)
            guard let name = component.name else { continue }
            if app.components == nil { app.components = [:] }
            app.components?[name] = component
        }

        let screenFiles = Self.findYAMLFiles(in: dirPath, excluding: "app.yaml")
        if !screenFiles.isEmpty {
            for filePath in screenFiles {
                let yaml = try String(contentsOfFile: filePath, encoding: .utf8)
                let screen = try decoder.decode(ScreenDefinition.self, from: yaml)
                app.screens.append(screen)
            }
        }

        return app
    }

    /// Merges a directory back into a single YAML string for hot reload broadcast.
    /// Reads app.yaml, component files, and all screen YAML files from subdirectories.
    public func mergeDirectoryToYAML(at dirPath: String) throws -> String {
        let appFile = (dirPath as NSString).appendingPathComponent("app.yaml")
        var appYaml = try String(contentsOfFile: appFile, encoding: .utf8)

        let componentFiles = Self.findComponentFiles(in: dirPath)
        if !componentFiles.isEmpty {
            if !appYaml.contains("\ncomponents:") && !appYaml.contains("\ncomponents :") {
                appYaml += "\ncomponents:\n"
            }
            for filePath in componentFiles {
                let compYaml = try String(contentsOfFile: filePath, encoding: .utf8)
                let lines = compYaml.components(separatedBy: "\n")
                var name: String?
                var bodyLines: [String] = []
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("name:") && name == nil {
                        name = trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces)
                    } else {
                        bodyLines.append(line)
                    }
                }
                guard let componentName = name, !componentName.isEmpty else { continue }
                let indentedBody = bodyLines
                    .map { $0.isEmpty ? "" : "    \($0)" }
                    .joined(separator: "\n")
                appYaml += "  \(componentName):\n\(indentedBody)\n"
            }
        }

        let screenFiles = Self.findYAMLFiles(in: dirPath, excluding: "app.yaml")
        if !screenFiles.isEmpty {
            if !appYaml.contains("\nscreens:") && !appYaml.contains("\nscreens :") {
                appYaml += "\nscreens:\n"
            }

            for filePath in screenFiles {
                let screenYaml = try String(contentsOfFile: filePath, encoding: .utf8)
                appYaml += "  - " + screenYaml.replacingOccurrences(
                    of: "\n",
                    with: "\n    "
                ) + "\n"
            }
        }

        return appYaml
    }

    /// Directories that should never be scanned for YAML files (build artifacts, etc.)
    private static let ignoredDirectoryNames: Set<String> = ["build", "node_modules", ".build", "DerivedData", "assets"]

    /// Whether a relative path passes through an ignored directory.
    private static func isInsideIgnoredDirectory(_ relative: String) -> Bool {
        let components = (relative as NSString).pathComponents
        return components.contains(where: { ignoredDirectoryNames.contains($0) })
    }

    /// Recursively finds all .yaml/.yml files in subdirectories of `dirPath`,
    /// excluding app.yaml files, component files, and build artifacts.
    /// Returns sorted absolute paths.
    public static func findYAMLFiles(in dirPath: String, excluding rootFile: String) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: dirPath) else { return [] }

        var results: [String] = []
        while let relative = enumerator.nextObject() as? String {
            let filename = (relative as NSString).lastPathComponent
            if filename == rootFile { continue }
            if filename.hasPrefix(".") { continue }
            if isInsideIgnoredDirectory(relative) { continue }
            guard relative.hasSuffix(".yaml") || relative.hasSuffix(".yml") else { continue }
            guard !relative.hasSuffix(".component.yaml") else { continue }

            results.append((dirPath as NSString).appendingPathComponent(relative))
        }
        return results.sorted()
    }

    /// Recursively finds all *.component.yaml files in `dirPath`.
    /// Returns sorted absolute paths.
    public static func findComponentFiles(in dirPath: String) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: dirPath) else { return [] }

        var results: [String] = []
        while let relative = enumerator.nextObject() as? String {
            let filename = (relative as NSString).lastPathComponent
            if filename.hasPrefix(".") { continue }
            if isInsideIgnoredDirectory(relative) { continue }
            guard relative.hasSuffix(".component.yaml") else { continue }

            results.append((dirPath as NSString).appendingPathComponent(relative))
        }
        return results.sorted()
    }

    /// Detect whether a path is a directory (multi-file project) or a single file
    public static func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
}

/// Errors produced during YAML app definition parsing.
public enum ParserError: Error, LocalizedError {
    case missingAppYaml(directory: String)

    public var errorDescription: String? {
        switch self {
        case .missingAppYaml(let dir):
            return "No app.yaml found in directory: \(dir)"
        }
    }
}
