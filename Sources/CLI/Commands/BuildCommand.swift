import ArgumentParser
import Foundation
import Core

/// Bundles a Melody project into an output directory for deployment.
struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Bundle a Melody app for deployment"
    )

    @Option(name: .shortAndLong, help: "Path to app.yaml file or project directory")
    var file: String = "app.yaml"

    @Option(name: .shortAndLong, help: "Output directory")
    var output: String = ".melody-build"

    func run() throws {
        let path = resolvePath(file)
        print("Building \(path)...")

        let parser = AppParser()
        let projectDir = AppParser.isDirectory(path) ? path : (path as NSString).deletingLastPathComponent
        let app = try parser.parseDirectory(at: projectDir)
        let mergedYaml = try parser.mergeDirectoryToYAML(at: projectDir)

        let outputPath = resolvePath(output)
        try FileManager.default.createDirectory(
            atPath: outputPath,
            withIntermediateDirectories: true
        )

        let destPath = (outputPath as NSString).appendingPathComponent("app.yaml")
        try mergedYaml.write(toFile: destPath, atomically: true, encoding: .utf8)

        let sourceDir = projectDir
        let componentsDir = (sourceDir as NSString).appendingPathComponent("components")
        let destComponentsDir = (outputPath as NSString).appendingPathComponent("components")
        try FileManager.default.replaceItem(at: destComponentsDir, with: componentsDir)

        let assetsDir = (sourceDir as NSString).appendingPathComponent("assets")
        let destAssetsDir = (outputPath as NSString).appendingPathComponent("assets")
        try FileManager.default.replaceItem(at: destAssetsDir, with: assetsDir)

        let widgetFiles = AppParser.findWidgetFiles(in: sourceDir)
        if !widgetFiles.isEmpty {
            let destWidgetsDir = (outputPath as NSString).appendingPathComponent("widgets")
            try FileManager.default.createDirectory(atPath: destWidgetsDir, withIntermediateDirectories: true)
            for filePath in widgetFiles {
                let filename = (filePath as NSString).lastPathComponent
                let dest = (destWidgetsDir as NSString).appendingPathComponent(filename)
                try FileManager.default.replaceItem(at: dest, with: filePath)
            }
        }

        let widgetCount = app.widgets?.count ?? 0
        print("✓ Built '\(app.app.name)' → \(outputPath)")
        print("  \(app.screens.count) screen(s), \(widgetCount) widget(s) bundled")
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        return (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(path)
    }
}

extension FileManager {
    /// Copies `source` to `destination`, removing any existing item at the destination.
    /// No-op if `source` does not exist.
    func replaceItem(at destination: String, with source: String) throws {
        guard fileExists(atPath: source) else { return }
        if fileExists(atPath: destination) {
            try removeItem(atPath: destination)
        }
        try copyItem(atPath: source, toPath: destination)
    }
}
