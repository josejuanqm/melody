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
          lua: |
            function formatDate(ts, fmt)
              return os.date(fmt or "%b %d, %Y", ts)
            end
            function formatTime(ts, fmt)
              return os.date(fmt or "%I:%M %p", ts)
            end
            function formatDateTime(ts, fmt)
              return os.date(fmt or "%b %d, %Y %I:%M %p", ts)
            end
            function timeAgo(ts)
              local d = os.time() - ts
              if d < 60 then return "just now"
              elseif d < 3600 then return math.floor(d / 60) .. "m ago"
              elseif d < 86400 then return math.floor(d / 3600) .. "h ago"
              elseif d < 604800 then return math.floor(d / 86400) .. "d ago"
              else return os.date("%b %d", ts) end
            end
          theme:
            primary: "#6366f1"
            secondary: "#a855f7"
            background: "#f2f2f7"
            colors:
              surface: "#ffffff"
              surfaceElevated: "#f0eef6"
              textPrimary: "#000000"
              textSecondary: "#8e8e93"
              textTertiary: "#aeaeb2"
              accent: "#6366f1"
            dark:
              background: "#000000"
              colors:
                surface: "#1c1c1e"
                surfaceElevated: "#2c2c2e"
                textPrimary: "#ffffff"
                textSecondary: "#8e8e93"
                textTertiary: "#636366"

        screens:
          - id: home
            path: /
            title: \(name)
            titleDisplayMode: large
            wrapper: scroll
            state:
              count: 0

            body:
              # Hero
              - component: stack
                direction: vertical
                style:
                  spacing: 8
                  alignment: center
                  paddingTop: 32
                  paddingBottom: 24
                  paddingHorizontal: 16
                  maxWidth: full
                children:
                  - component: text
                    text: "Welcome to \(name)"
                    style:
                      fontSize: 28
                      fontWeight: bold
                      color: "theme.textPrimary"
                      alignment: center
                  - component: text
                    text: "Edit app.yaml to start building your app"
                    style:
                      fontSize: 15
                      color: "theme.textSecondary"
                      alignment: center

              # Counter card
              - component: stack
                direction: vertical
                style:
                  spacing: 16
                  padding: 20
                  marginHorizontal: 16
                  marginBottom: 12
                  backgroundColor: "theme.surface"
                  borderRadius: 16
                  alignment: center
                children:
                  - component: text
                    text: "{{ 'Count: ' .. state.count }}"
                    style:
                      fontSize: 48
                      fontWeight: bold
                      fontDesign: rounded
                      color: "theme.accent"
                  - component: stack
                    direction: horizontal
                    style:
                      spacing: 12
                    children:
                      - component: button
                        label: "Decrement"
                        systemImage: minus
                        onTap: "state.count = math.max(0, state.count - 1)"
                        style:
                          fontSize: 15
                          fontWeight: semibold
                          color: "theme.accent"
                          backgroundColor: "theme.surfaceElevated"
                          padding: 14
                          borderRadius: 12
                      - component: button
                        label: "Increment"
                        systemImage: plus
                        onTap: "state.count = state.count + 1"
                        style:
                          fontSize: 15
                          fontWeight: semibold
                          color: "#ffffff"
                          backgroundColor: "theme.accent"
                          padding: 14
                          borderRadius: 12

              # Getting started steps
              - component: stack
                direction: vertical
                style:
                  spacing: 0
                  marginHorizontal: 16
                  marginBottom: 12
                  backgroundColor: "theme.surface"
                  borderRadius: 16
                children:
                  - component: stack
                    direction: vertical
                    style:
                      spacing: 2
                      padding: 16
                      alignment: leading
                      maxWidth: full
                    children:
                      - component: text
                        text: "Edit Your App"
                        style:
                          fontSize: 16
                          fontWeight: semibold
                          color: "theme.textPrimary"
                      - component: text
                        text: "Open app.yaml and start changing things"
                        style:
                          fontSize: 13
                          color: "theme.textSecondary"
                  - component: divider
                  - component: stack
                    direction: vertical
                    style:
                      spacing: 2
                      padding: 16
                      alignment: leading
                      maxWidth: full
                    children:
                      - component: text
                        text: "Hot Reload"
                        style:
                          fontSize: 16
                          fontWeight: semibold
                          color: "theme.textPrimary"
                      - component: text
                        text: "Run melody dev and see changes instantly"
                        style:
                          fontSize: 13
                          color: "theme.textSecondary"
                  - component: divider
                  - component: stack
                    direction: vertical
                    style:
                      spacing: 2
                      padding: 16
                      alignment: leading
                      maxWidth: full
                    children:
                      - component: text
                        text: "Add Components"
                        style:
                          fontSize: 16
                          fontWeight: semibold
                          color: "theme.textPrimary"
                      - component: text
                        text: "Text, buttons, lists, charts, and more"
                        style:
                          fontSize: 13
                          color: "theme.textSecondary"
                  - component: divider
                  - component: stack
                    direction: vertical
                    style:
                      spacing: 2
                      padding: 16
                      alignment: leading
                      maxWidth: full
                    children:
                      - component: text
                        text: "Add Screens"
                        style:
                          fontSize: 16
                          fontWeight: semibold
                          color: "theme.textPrimary"
                      - component: text
                        text: "Navigate between screens with Lua"
                        style:
                          fontSize: 13
                          color: "theme.textSecondary"

              # Footer
              - component: text
                text: "Built with Melody"
                style:
                  fontSize: 13
                  color: "theme.textTertiary"
                  paddingTop: 8
                  paddingBottom: 32
                  paddingHorizontal: 32
                  alignment: leading
                  maxWidth: full
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

        let widgetsDir = (projectDir as NSString).appendingPathComponent("widgets")
        try FileManager.default.createDirectory(
            atPath: widgetsDir,
            withIntermediateDirectories: true
        )

        let melodyVersion = MelodyCLI.configuration.version
        try XcodeProjectGenerator.generate(
            name: name,
            bundleId: bundleId,
            projectDir: projectDir,
            melodyVersion: melodyVersion
        )

        try AndroidProjectGenerator.generate(
            name: name,
            bundleId: bundleId,
            projectDir: projectDir,
            melodyVersion: melodyVersion
        )

        print("✓ Created project '\(name)' at \(projectDir)")
        print("  → app.yaml")
        print("  → components/")
        print("  → screens/")
        print("  → widgets/")
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
