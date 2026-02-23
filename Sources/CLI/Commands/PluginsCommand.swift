import ArgumentParser
import Foundation
import Core
import Yams

/// Parent command for managing Melody plugins (install, update).
struct PluginsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plugins",
        abstract: "Manage Melody plugins",
        subcommands: [InstallCommand.self]
    )

    /// Clones plugin repositories and generates native registration code for iOS and Android.
    struct InstallCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Install plugins declared in app.yaml"
        )

        @Option(name: .shortAndLong, help: "Path to app.yaml file or project directory")
        var file: String = "."

        func run() throws {
            let projectDir = resolveProjectDir(file)
            let parser = AppParser()
            let app = try parser.parseDirectory(at: projectDir)

            guard let plugins = app.app.plugins, !plugins.isEmpty else {
                print("No plugins declared in app.yaml")
                return
            }

            let pluginsDir = (projectDir as NSString).appendingPathComponent(".melody/plugins")
            try FileManager.default.createDirectory(atPath: pluginsDir, withIntermediateDirectories: true)

            var manifests: [PluginManifest] = []
            var luaPreludes: [String] = []

            for (name, url) in plugins {
                print("Installing plugin '\(name)' from \(url)...")

                let pluginDir = (pluginsDir as NSString).appendingPathComponent(name)

                if FileManager.default.fileExists(atPath: pluginDir) {
                    let pullResult = shell("git", "-C", pluginDir, "pull", "--ff-only")
                    if pullResult != 0 {
                        print("  Warning: git pull failed for \(name), using existing checkout")
                    }
                } else {
                    let cloneResult = shell("git", "clone", "--depth", "1", url, pluginDir)
                    if cloneResult != 0 {
                        throw PluginError.cloneFailed(name: name, url: url)
                    }
                }

                let manifestPath = (pluginDir as NSString).appendingPathComponent("plugin.yaml")
                guard FileManager.default.fileExists(atPath: manifestPath) else {
                    throw PluginError.missingManifest(name: name)
                }

                let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
                let manifest = try YAMLDecoder().decode(PluginManifest.self, from: manifestData)
                manifests.append(manifest)

                if let ios = manifest.ios {
                    let iosDestDir = (projectDir as NSString).appendingPathComponent("ExampleApp/Plugins/\(name)")
                    try FileManager.default.createDirectory(atPath: iosDestDir, withIntermediateDirectories: true)
                    for source in ios.sources {
                        let srcPath = (pluginDir as NSString).appendingPathComponent(source)
                        let filename = (source as NSString).lastPathComponent
                        let destPath = (iosDestDir as NSString).appendingPathComponent(filename)
                        try FileManager.default.replaceItem(at: destPath, with: srcPath)
                    }
                }

                if let android = manifest.android {
                    let androidDestDir = (projectDir as NSString).appendingPathComponent("android/example-app/src/main/java/plugins/\(name)")
                    try FileManager.default.createDirectory(atPath: androidDestDir, withIntermediateDirectories: true)
                    for source in android.sources {
                        let srcPath = (pluginDir as NSString).appendingPathComponent(source)
                        let filename = (source as NSString).lastPathComponent
                        let destPath = (androidDestDir as NSString).appendingPathComponent(filename)
                        try FileManager.default.replaceItem(at: destPath, with: srcPath)
                    }
                }

                if let luaFiles = manifest.lua {
                    for luaFile in luaFiles {
                        let luaPath = (pluginDir as NSString).appendingPathComponent(luaFile)
                        if FileManager.default.fileExists(atPath: luaPath) {
                            let content = try String(contentsOfFile: luaPath, encoding: .utf8)
                            luaPreludes.append("-- Plugin: \(name)\n\(content)")
                        }
                    }
                }

                print("  ✓ Installed '\(name)'")
            }

            try generateIOSRegistry(manifests: manifests, projectDir: projectDir)
            try generateAndroidRegistry(manifests: manifests, projectDir: projectDir)

            if !luaPreludes.isEmpty {
                let preludePath = (projectDir as NSString).appendingPathComponent(".melody/plugins/prelude.lua")
                try luaPreludes.joined(separator: "\n\n").write(toFile: preludePath, atomically: true, encoding: .utf8)
                print("  ✓ Generated Lua prelude (\(luaPreludes.count) file(s))")
            }

            print("\n✓ Installed \(manifests.count) plugin(s)")
        }

        private func generateIOSRegistry(manifests: [PluginManifest], projectDir: String) throws {
            let destDir = (projectDir as NSString).appendingPathComponent("ExampleApp/Plugins")
            try FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)

            let classNames = manifests.compactMap { manifest -> String? in
                guard manifest.ios != nil else { return nil }
                return swiftClassName(from: manifest.name)
            }

            let entries = classNames.map { "    \($0)()," }.joined(separator: "\n")
            let content = """
            import Runtime

            let melodyPlugins: [MelodyPlugin] = [
            \(entries)
            ]
            """

            let path = (destDir as NSString).appendingPathComponent("MelodyPluginRegistry.swift")
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            print("  ✓ Generated iOS plugin registry")
        }

        private func generateAndroidRegistry(manifests: [PluginManifest], projectDir: String) throws {
            let destDir = (projectDir as NSString).appendingPathComponent("android/example-app/src/main/java/plugins")
            try FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)

            let classNames = manifests.compactMap { manifest -> String? in
                guard manifest.android != nil else { return nil }
                return swiftClassName(from: manifest.name)
            }

            let entries = classNames.map { "    \($0)()," }.joined(separator: "\n")
            let content = """
            package plugins

            import com.melody.runtime.plugin.MelodyPlugin

            val melodyPlugins: List<MelodyPlugin> = listOf(
            \(entries)
            )
            """

            let path = (destDir as NSString).appendingPathComponent("MelodyPluginRegistry.kt")
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            print("  ✓ Generated Android plugin registry")
        }

        private func swiftClassName(from pluginName: String) -> String {
            let parts = pluginName.split(separator: "-").map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            return parts.joined() + "Plugin"
        }

        private func resolveProjectDir(_ path: String) -> String {
            let resolved = path.hasPrefix("/") ? path : (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(path)
            if AppParser.isDirectory(resolved) {
                return resolved
            }
            return (resolved as NSString).deletingLastPathComponent
        }

        @discardableResult
        private func shell(_ args: String...) -> Int32 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = args
            try? process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }
    }
}

private enum PluginError: Error, LocalizedError {
    case cloneFailed(name: String, url: String)
    case missingManifest(name: String)

    var errorDescription: String? {
        switch self {
        case .cloneFailed(let name, let url):
            return "Failed to clone plugin '\(name)' from \(url)"
        case .missingManifest(let name):
            return "Plugin '\(name)' is missing plugin.yaml manifest"
        }
    }
}
