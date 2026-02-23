import ArgumentParser
import Foundation
import Core

/// Scaffolds a new Melody project with YAML, Xcode, and Android boilerplate.
struct CreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new Melody project"
    )

    @Argument(help: "The name of the project to create")
    var name: String

    @Option(name: .shortAndLong, help: "Directory to create the project in")
    var directory: String?

    func run() throws {
        let baseDir = directory ?? FileManager.default.currentDirectoryPath
        let projectDir = (baseDir as NSString).appendingPathComponent(name)

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: projectDir, isDirectory: &isDir), isDir.boolValue {
            throw ValidationError("Directory '\(projectDir)' already exists. Remove it first or choose a different name.")
        }

        try FileManager.default.createDirectory(
            atPath: projectDir,
            withIntermediateDirectories: true
        )

        let bundleId = "com.melody.\(name.lowercased())"

        let appYaml = """
        app:
          name: \(name)
          id: \(bundleId)
          theme:
            primary: "#6366f1"

        screens:
          - id: home
            path: /
            title: \(name)
            state:
              count: 0

            body:
              - component: Stack
                direction: vertical
                style:
                  spacing: 16
                  alignment: center
                children:
                  - component: Text
                    text: "Welcome to \(name)!"
                    style:
                      fontSize: 28
                      fontWeight: bold

                  - component: Text
                    text: "{{ 'Count: ' .. state.count }}"
                    style:
                      fontSize: 18

                  - component: Button
                    label: "Tap me"
                    onTap: |
                      state.count = state.count + 1
                      melody.log("Count is now " .. state.count)
        """

        let appYamlPath = (projectDir as NSString).appendingPathComponent("app.yaml")
        try appYaml.write(toFile: appYamlPath, atomically: true, encoding: .utf8)

        let componentsDir = (projectDir as NSString).appendingPathComponent("components")
        try FileManager.default.createDirectory(
            atPath: componentsDir,
            withIntermediateDirectories: true
        )

        let screensDir = (projectDir as NSString).appendingPathComponent("screens")
        try FileManager.default.createDirectory(
            atPath: screensDir,
            withIntermediateDirectories: true
        )

        let assetsDir = (projectDir as NSString).appendingPathComponent("assets")
        try FileManager.default.createDirectory(
            atPath: assetsDir,
            withIntermediateDirectories: true
        )

        let melodyRepoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        let melodyPackagePath = XcodeProjectGenerator.relativePath(
            from: projectDir, to: melodyRepoRoot
        )
        try XcodeProjectGenerator.generate(
            name: name,
            bundleId: bundleId,
            projectDir: projectDir,
            melodyPackagePath: melodyPackagePath
        )

        try AndroidProjectGenerator.generate(
            name: name,
            bundleId: bundleId,
            projectDir: projectDir,
            melodyRepoRoot: melodyRepoRoot
        )

        print("✓ Created project '\(name)' at \(projectDir)")
        print("  → app.yaml")
        print("  → components/")
        print("  → screens/")
        print("  → assets/")
        print("  → \(name).xcodeproj/")
        print("  → App.swift")
        print("  → DevConfig.swift")
        print("  → Manifest.xcconfig")
        print("  → Info.plist")
        print("  → Assets.xcassets/")
        print("  → android/")
        print("")
        print("Next steps:")
        print("  cd \(name)")
        print("  open \(name).xcodeproj    # Build & run in Xcode")
        print("  studio android            # Open in Android Studio")
        print("  melody dev                # Start dev server with hot reload")
    }
}
