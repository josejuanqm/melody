import ArgumentParser
import Foundation
import Core
import Yams

#if canImport(AppIntents)
import AppIntents
#endif

/// Generates iOS widget extension Swift files from *.widget.yaml definitions.
struct GenerateWidgetsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-widgets",
        abstract: "Generate iOS widget extension Swift files from widget YAML definitions"
    )

    @Option(name: .shortAndLong, help: "Path to project directory containing app.yaml")
    var file: String = "."

    @Option(name: .shortAndLong, help: "Output directory for generated widget files (default: {Name}Widgets/)")
    var output: String?

    func run() throws {
        let projectDir = resolvePath(file)
        let parser = AppParser()
        let dir = AppParser.isDirectory(projectDir)
            ? projectDir
            : (projectDir as NSString).deletingLastPathComponent
        let app = try parser.parseDirectory(at: dir)

        let widgetFiles = AppParser.findWidgetFiles(in: dir)
        guard !widgetFiles.isEmpty else {
            print("No *.widget.yaml files found in \(dir)")
            return
        }

        let name = app.app.name
        let bundleId = app.app.id ?? "com.melody.\(name.lowercased())"
        let appLuaPrelude = app.app.lua

        let outputDir: String
        if let output = output {
            outputDir = resolvePath(output)
        } else {
            outputDir = (dir as NSString).appendingPathComponent("\(name)Widgets")
        }

        let fm = FileManager.default
        try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        var widgetEntries: [(id: String, swiftName: String)] = []

        for filePath in widgetFiles.sorted() {
            let rawYAML = try String(contentsOfFile: filePath, encoding: .utf8)
            guard let parsed = try Yams.load(yaml: rawYAML) as? [String: Any] else {
                print("  ⚠ Skipping \((filePath as NSString).lastPathComponent): invalid YAML")
                continue
            }

            let widgetId = parsed["id"] as? String ?? (filePath as NSString).lastPathComponent
                .replacingOccurrences(of: ".widget.yaml", with: "")
            let widgetName = parsed["name"] as? String ?? widgetId
            let widgetDesc = parsed["description"] as? String ?? widgetName

            let familiesRaw = parsed["families"] as? [String] ?? ["Small"]
            let familiesSwift = familiesRaw.map { family -> String in
                switch family.lowercased() {
                case "small": return ".systemSmall"
                case "medium": return ".systemMedium"
                case "large": return ".systemLarge"
                default: return ".systemSmall"
                }
            }
            let familiesStr = familiesSwift.joined(separator: ", ")

            let swiftName = widgetSwiftName(widgetId)
            widgetEntries.append((id: widgetId, swiftName: swiftName))

            let escapedYAML = rawYAML.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"\"\"", with: "\\\"\\\"\\\"")

            let hasConfigure = parsed["configure"] != nil
            let widgetSwift: String

            if hasConfigure {
                // Parse widget definition to extract parameters
                let decoder = YAMLDecoder()
                let widgetDef = try decoder.decode(WidgetDefinition.self, from: rawYAML)
                let configure = widgetDef.configure!

                widgetSwift = generateParameterBasedWidget(
                    swiftName: swiftName,
                    widgetId: widgetId,
                    widgetName: widgetName,
                    widgetDesc: widgetDesc,
                    familiesStr: familiesStr,
                    escapedYAML: escapedYAML,
                    bundleId: bundleId,
                    configure: configure,
                    appLuaPrelude: appLuaPrelude
                )
            } else {
                widgetSwift = generateStaticWidget(
                    swiftName: swiftName,
                    widgetId: widgetId,
                    widgetName: widgetName,
                    widgetDesc: widgetDesc,
                    familiesStr: familiesStr,
                    escapedYAML: escapedYAML,
                    bundleId: bundleId
                )
            }

            let widgetPath = (outputDir as NSString).appendingPathComponent("\(swiftName)Widget.swift")
            try widgetSwift.write(toFile: widgetPath, atomically: true, encoding: .utf8)
        }

        let bundleEntries = widgetEntries.sorted(by: { $0.id < $1.id })
            .map { "\($0.swiftName)Widget()" }
            .joined(separator: "\n        ")

        let bundleSwift = """
        import WidgetKit
        import SwiftUI

        @main
        struct \(name)WidgetBundle: WidgetBundle {
            var body: some Widget {
                \(bundleEntries)
            }
        }
        """

        let bundlePath = (outputDir as NSString).appendingPathComponent("WidgetBundle.swift")
        try bundleSwift.write(toFile: bundlePath, atomically: true, encoding: .utf8)

        let entitlements = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>com.apple.security.application-groups</key>
        \t<array>
        \t\t<string>group.\(bundleId)</string>
        \t</array>
        </dict>
        </plist>
        """

        let entitlementsPath = (outputDir as NSString).appendingPathComponent("\(name)Widgets.entitlements")
        try entitlements.write(toFile: entitlementsPath, atomically: true, encoding: .utf8)

        let appEntitlementsPath = (dir as NSString).appendingPathComponent("\(name).entitlements")
        if !fm.fileExists(atPath: appEntitlementsPath) {
            try entitlements.write(toFile: appEntitlementsPath, atomically: true, encoding: .utf8)
        }

        print("✓ Generated \(widgetEntries.count) widget(s) → \(outputDir)")
        for entry in widgetEntries.sorted(by: { $0.id < $1.id }) {
            print("  → \(entry.swiftName)Widget.swift")
        }
        print("  → WidgetBundle.swift")
        print("  → \(name)Widgets.entitlements")
    }

    // MARK: - Static Widget (no configure)

    private func generateStaticWidget(
        swiftName: String,
        widgetId: String,
        widgetName: String,
        widgetDesc: String,
        familiesStr: String,
        escapedYAML: String,
        bundleId: String
    ) -> String {
        return """
        import WidgetKit
        import SwiftUI
        import Widgets
        import Core

        struct \(swiftName)Widget: Widget {
            let kind: String = "\(widgetId)"

            private let widgetYAML = \"\"\"
        \(escapedYAML)
        \"\"\"

            var body: some WidgetConfiguration {
                StaticConfiguration(kind: kind, provider: MelodyTimelineProvider(widgetYAML: widgetYAML, suiteName: "group.\(bundleId)")) { entry in
                    MelodyWidgetView(entry: entry)
                }
                .configurationDisplayName("\(widgetName)")
                .description("\(widgetDesc)")
                .supportedFamilies([\(familiesStr)])
            }
        }
        """
    }

    // MARK: - Parameter-Based Widget (with configure)

    private func generateParameterBasedWidget(
        swiftName: String,
        widgetId: String,
        widgetName: String,
        widgetDesc: String,
        familiesStr: String,
        escapedYAML: String,
        bundleId: String,
        configure: WidgetConfigureDefinition,
        appLuaPrelude: String?
    ) -> String {
        let suiteName = "group.\(bundleId)"
        let parameters = configure.parameters

        // Escape the lua prelude for embedding as a Swift string
        let escapedPrelude = (appLuaPrelude ?? "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        // Generate entity types and queries for each parameter
        var entityDefinitions = ""
        for param in parameters {
            let entityName = "\(swiftName)\(param.id.capitalized)Entity"
            let queryName = "\(swiftName)\(param.id.capitalized)Query"
            let escapedQuery = param.query
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")

            let parentDeps = param.dependsOn ?? []
            let hasParentDeps = !parentDeps.isEmpty

            // Entity struct
            entityDefinitions += """

            struct \(entityName): AppEntity {
                static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "\(param.title)")
                static let defaultQuery = \(queryName)()

                var id: String
                var name: String
                var subtitle: String?

                var displayRepresentation: DisplayRepresentation {
                    if let subtitle {
                        return DisplayRepresentation(title: "\\(name)", subtitle: "\\(subtitle)")
                    }
                    return DisplayRepresentation(title: "\\(name)")
                }

                init(id: String, name: String, subtitle: String? = nil) {
                    self.id = id
                    self.name = name
                    self.subtitle = subtitle
                }
            }

            """

            // Entity query
            if hasParentDeps {
                // Dependent query using @IntentParameterDependency
                entityDefinitions += """

            struct \(queryName): EntityQuery {
                @IntentParameterDependency<\(swiftName)Intent>(\(parentDeps.map { "\\.$\($0)" }.joined(separator: ", ")))
                var intent

                func entities(for identifiers: [\(entityName).ID]) async throws -> [\(entityName)] {
                    let all = try await suggestedEntities()
                    return all.filter { identifiers.contains($0.id) }
                }

                func suggestedEntities() async throws -> [\(entityName)] {
                    var parentParams: [String: String] = [:]
            \(parentDeps.map { dep in
                "        if let \(dep)Entity = intent?.\(dep) { parentParams[\"\(dep)\"] = \(dep)Entity.id }"
            }.joined(separator: "\n"))
                    let runner = WidgetQueryRunner(suiteName: "\(suiteName)", appLuaPrelude: \(swiftName)Widget.appLuaPrelude)
                    let results = runner.runQuery("\(escapedQuery)", params: parentParams)
                    return results.map { \(entityName)(id: $0.id, name: $0.name, subtitle: $0.subtitle) }
                }
            }

            """
            } else {
                // Root query (no dependencies)
                entityDefinitions += """

            struct \(queryName): EntityQuery {
                func entities(for identifiers: [\(entityName).ID]) async throws -> [\(entityName)] {
                    let all = try await suggestedEntities()
                    return all.filter { identifiers.contains($0.id) }
                }

                func suggestedEntities() async throws -> [\(entityName)] {
                    let runner = WidgetQueryRunner(suiteName: "\(suiteName)", appLuaPrelude: \(swiftName)Widget.appLuaPrelude)
                    let results = runner.runQuery("\(escapedQuery)")
                    return results.map { \(entityName)(id: $0.id, name: $0.name, subtitle: $0.subtitle) }
                }
            }

            """
            }
        }

        // Generate the intent
        let parameterDecls = parameters.map { param in
            let entityName = "\(swiftName)\(param.id.capitalized)Entity"
            return "    @Parameter(title: \"\(param.title)\") var \(param.id): \(entityName)?"
        }.joined(separator: "\n")

        let escapedResolve = (configure.resolve ?? "return params")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        // Build the timeline provider
        let paramExtractions = parameters.map { param in
            "        if let \(param.id) = configuration.\(param.id) { selectedParams[\"\(param.id)\"] = \(param.id).id }"
        }.joined(separator: "\n")

        return """
        import WidgetKit
        import SwiftUI
        import AppIntents
        import Widgets
        import Core
        import Yams
        \(entityDefinitions)
        struct \(swiftName)Intent: WidgetConfigurationIntent {
            static let title: LocalizedStringResource = "\(configure.title ?? "Configure")"
            static let description = IntentDescription("\(widgetDesc)")

        \(parameterDecls)

            init() {}
        }

        struct \(swiftName)TimelineProvider: AppIntentTimelineProvider {
            let widgetYAML: String
            let suiteName: String

            func placeholder(in context: Context) -> MelodyWidgetEntry {
                let definition = parseDefinition()
                let family = mapFamily(context.family)
                return MelodyWidgetEntry(date: .now, widgetDefinition: definition, data: [:], themeColors: loadThemeColors(), family: family)
            }

            func snapshot(for configuration: \(swiftName)Intent, in context: Context) async -> MelodyWidgetEntry {
                await makeEntry(for: configuration, in: context)
            }

            func timeline(for configuration: \(swiftName)Intent, in context: Context) async -> Timeline<MelodyWidgetEntry> {
                let entry = await makeEntry(for: configuration, in: context)
                let intervalMinutes = entry.widgetDefinition.refresh?.interval ?? 30
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: intervalMinutes, to: .now) ?? Date.now.addingTimeInterval(1800)
                return Timeline(entries: [entry], policy: .after(nextUpdate))
            }

            private func makeEntry(for configuration: \(swiftName)Intent, in context: Context) async -> MelodyWidgetEntry {
                let definition = parseDefinition()
                let family = mapFamily(context.family)
                let colors = loadThemeColors()

                // Extract selected parameter IDs
                var selectedParams: [String: String] = [:]
        \(paramExtractions)

                // Run resolve to get config data
                let runner = WidgetQueryRunner(suiteName: suiteName, appLuaPrelude: \(swiftName)Widget.appLuaPrelude)
                let configData = runner.runResolve("\(escapedResolve)", params: selectedParams)

                // Save config data for WidgetDataProvider
                let configKey = selectedParams.values.sorted().joined(separator: "-")
                if !configKey.isEmpty {
                    WidgetConfigStore.saveData(widgetId: configKey, data: configData, suiteName: suiteName)
                }

                // Resolve full widget data (store + config + fetch)
                let data = await WidgetDataProvider.resolve(widget: definition, widgetId: configKey.isEmpty ? nil : configKey, suiteName: suiteName)

                return MelodyWidgetEntry(date: .now, widgetDefinition: definition, data: data, themeColors: colors, family: family, configEntityId: configKey.isEmpty ? nil : configKey)
            }

            private func parseDefinition() -> WidgetDefinition {
                let decoder = YAMLDecoder()
                return (try? decoder.decode(WidgetDefinition.self, from: widgetYAML)) ?? WidgetDefinition(id: "unknown")
            }

            private func mapFamily(_ family: WidgetKit.WidgetFamily) -> Core.WidgetFamily {
                switch family {
                case .systemSmall: return .small
                case .systemMedium: return .medium
                case .systemLarge: return .large
                default: return .small
                }
            }

            private func loadThemeColors() -> [String: String] {
                let defaults = UserDefaults(suiteName: suiteName) ?? .standard
                guard let data = defaults.data(forKey: "melody.theme.colors"),
                      let colors = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    return [:]
                }
                return colors
            }
        }

        struct \(swiftName)Widget: Widget {
            let kind: String = "\(widgetId)"

            nonisolated static let appLuaPrelude: String? = \(appLuaPrelude != nil ? "\"\(escapedPrelude)\"" : "nil")

            private let widgetYAML = \"\"\"
        \(escapedYAML)
        \"\"\"

            var body: some WidgetConfiguration {
                AppIntentConfiguration(kind: kind, intent: \(swiftName)Intent.self, provider: \(swiftName)TimelineProvider(widgetYAML: widgetYAML, suiteName: "\(suiteName)")) { entry in
                    MelodyWidgetView(entry: entry)
                }
                .configurationDisplayName("\(widgetName)")
                .description("\(widgetDesc)")
                .supportedFamilies([\(familiesStr)])
            }
        }
        """
    }

    private func widgetSwiftName(_ id: String) -> String {
        id.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
            .split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        return (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(path)
    }
}
