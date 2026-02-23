import ArgumentParser
import Core
import Foundation

/// Starts the development server with file watching, hot reload, and optional native preview.
struct DevCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dev",
        abstract: "Start the development server with live preview"
    )

    @Option(name: .shortAndLong, help: "Path to app.yaml file")
    var file: String = "app.yaml"

    @Option(name: .shortAndLong, help: "Port for the WebSocket server")
    var port: Int = 8375

    @Option(name: .long, help: "Preview platform: macos, ios, or android")
    var platform: Platform = .macos

    @Option(name: .long, help: "iOS Simulator device name")
    var simulator: String = "iPhone 16"

    @Flag(name: .long, help: "Build and run on a physical iOS device via USB")
    var device: Bool = false

    @Flag(name: .long, help: "Start the dev server without launching a preview (hot reload only)")
    var noPreview: Bool = false

    func run() throws {
        let path = resolvePath(file)
        let parser = AppParser()
        let projectDir =
            AppParser.isDirectory(path) ? path : (path as NSString).deletingLastPathComponent

        let app = try parser.parseDirectory(at: projectDir)
        let initialYaml = try parser.mergeDirectoryToYAML(at: projectDir)

        let devHost = device ? try getLocalIPAddress() : "localhost"

        var projectInfo: ProjectInfo?
        if platform == .ios || platform == .android {
            projectInfo = try findProject(in: projectDir, app: app)
        }

        if platform == .ios, let info = projectInfo {
            writeDevConfig(host: devHost, port: port, projectDir: info.projectDir)
        }

        let server = DevWebSocketServer(port: UInt16(port))
        try server.start()
        server.broadcast(yaml: initialYaml)

        let assetPort = port + 1
        let fileServer = StaticFileServer(port: UInt16(assetPort), rootPath: projectDir)
        try fileServer.start()

        let localIP = try? getLocalIPAddress()

        print("🎵 Melody Dev")
        print("   App: \(app.app.name)")
        print("   Project: \(projectDir)")
        print("   Screens: \(app.screens.count)")
        if !noPreview {
            print("   Platform: \(platform.rawValue)\(device ? " (device)" : "")")
        }
        print("   Hot reload: ws://\(devHost):\(port)")
        print("   Assets: http://\(devHost):\(assetPort)")
        if let localIP {
            print("   Local IP: \(localIP)")
        }
        print("")

        watchDirectory(path: projectDir, parser: parser, server: server)
        listenForManualReload(path: projectDir, parser: parser, server: server, isDir: true)

        if noPreview {
            print("   Watching for changes (no preview)...")
            print("   Press r + Enter to reload manually")
            print("")
            dispatchMain()
        } else {
            switch platform {
            case .macos:
                print("   Watching for changes...")
                print("   Press r + Enter to reload manually")
                print("")
                let preview = DevPreviewWindow()
                preview.launch(app: app)

            case .ios:
                let info = projectInfo!
                if device {
                    try launchIOSDevice(project: info)
                } else {
                    print("   Simulator: \(simulator)")
                    print("")
                    try launchIOSSimulator(simulator: simulator, project: info)
                }
                print("")
                print("   Watching for changes...")
                print("   Press r + Enter to reload manually")
                print("")
                dispatchMain()

            case .android:
                let info = projectInfo!
                try launchAndroid(project: info)
                print("")
                print("   Watching for changes...")
                print("   Press r + Enter to reload manually")
                print("")
                dispatchMain()
            }
        }
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        return (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(path)
    }

    // MARK: - Project Detection

    /// Resolved metadata about a Melody project's Xcode configuration.
    struct ProjectInfo {
        let name: String
        let bundleId: String
        let projectDir: String
        let xcodeprojPath: String

        var scheme: String {
            ((xcodeprojPath as NSString).lastPathComponent as NSString).deletingPathExtension
        }
    }

    private func findProject(in projectDir: String, app: AppDefinition) throws -> ProjectInfo {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: projectDir) else {
            throw SimulatorError.projectNotFound
        }

        let xcodeprojs = contents.filter { $0.hasSuffix(".xcodeproj") }
        guard let xcodeprojName = xcodeprojs.first else {
            throw SimulatorError.projectNotFound
        }

        let xcodeprojPath = (projectDir as NSString).appendingPathComponent(xcodeprojName)
        let bundleId = app.app.id ?? "com.melody.\(app.app.name.lowercased())"
        return ProjectInfo(
            name: app.app.name,
            bundleId: bundleId,
            projectDir: projectDir,
            xcodeprojPath: xcodeprojPath
        )
    }

    // MARK: - iOS Simulator

    private func launchIOSSimulator(simulator: String, project: ProjectInfo) throws {
        print("   Building for iOS Simulator...")
        let derivedDataPath = "/tmp/melody-dev-build"
        let buildArgs = [
            "-project", project.xcodeprojPath,
            "-scheme", project.scheme,
            "-destination", "platform=iOS Simulator,name=\(simulator)",
            "-derivedDataPath", derivedDataPath,
            "-quiet",
        ]
        try runProcess("/usr/bin/xcodebuild", arguments: buildArgs)
        print("   ✓ Build succeeded")

        let appPath = try findBuiltApp(derivedDataPath: derivedDataPath)

        print("   Booting simulator...")
        _ = runProcessOptional("/usr/bin/xcrun", arguments: ["simctl", "boot", simulator])

        runProcessOptional("/usr/bin/open", arguments: ["-a", "Simulator"])

        print("   Installing app...")
        try runProcess("/usr/bin/xcrun", arguments: ["simctl", "install", "booted", appPath])
        print("   ✓ Installed")

        print("   Launching app...")
        try runProcess(
            "/usr/bin/xcrun", arguments: ["simctl", "launch", "booted", project.bundleId])
        print("   ✓ Launched on \(simulator)")
    }

    // MARK: - DevConfig Generation

    private func writeDevConfig(host: String, port: Int, projectDir: String) {
        let assetPort = port + 1
        let content =
            "#if MELODY_DEV\nlet melodyDevHost = \"\(host)\"\nlet melodyDevPort = \(port)\nlet melodyDevAssetPort = \(assetPort)\n#endif\n"
        let path = (projectDir as NSString).appendingPathComponent("DevConfig.swift")
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    // MARK: - Local IP

    private func getLocalIPAddress() throws -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            throw SimulatorError.commandFailed(
                command: "getifaddrs", output: "Failed to get network interfaces")
        }
        defer { freeifaddrs(ifaddr) }

        var result: String?
        var sequence = firstAddr.pointee
        while true {
            let interface = sequence
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        &addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST)
                    result = String(cString: hostname)
                    break
                }
            }
            guard let next = interface.ifa_next else { break }
            sequence = next.pointee
        }

        guard let ip = result else {
            throw SimulatorError.commandFailed(
                command: "getLocalIPAddress",
                output: "Could not find en0 IPv4 address. Make sure you're connected to WiFi.")
        }
        return ip
    }

    // MARK: - iOS Physical Device

    private func launchIOSDevice(project: ProjectInfo) throws {
        print("   Building for iOS device...")
        let derivedDataPath = "/tmp/melody-dev-build"
        let buildArgs = [
            "-project", project.xcodeprojPath,
            "-scheme", project.scheme,
            "-destination", "generic/platform=iOS",
            "-derivedDataPath", derivedDataPath,
            "-allowProvisioningUpdates",
            "-quiet",
        ]
        try runProcess("/usr/bin/xcodebuild", arguments: buildArgs)
        print("   ✓ Build succeeded")

        let appPath = try findBuiltDeviceApp(derivedDataPath: derivedDataPath)

        print("   Looking for connected device...")
        let udid = try findConnectedDeviceUDID()
        print("   ✓ Found device: \(udid)")

        print("   Installing app...")
        try runProcess(
            "/usr/bin/xcrun",
            arguments: [
                "devicectl", "device", "install", "app",
                "--device", udid, appPath,
            ])
        print("   ✓ Installed")

        print("   Launching app...")
        try runProcess(
            "/usr/bin/xcrun",
            arguments: [
                "devicectl", "device", "process", "launch",
                "--device", udid, project.bundleId,
            ])
        print("   ✓ Launched on device")
    }

    // MARK: - Android

    private func launchAndroid(project: ProjectInfo) throws {
        let androidDir = (project.projectDir as NSString).appendingPathComponent("android")
        guard FileManager.default.fileExists(atPath: androidDir) else {
            throw SimulatorError.commandFailed(
                command: "launchAndroid",
                output:
                    "No android/ directory found in \(project.projectDir). Run `melody create` to generate one."
            )
        }

        print("   Building Android APK...")
        let gradlew = (androidDir as NSString).appendingPathComponent("gradlew")
        let buildProcess = Process()
        buildProcess.executableURL = URL(fileURLWithPath: gradlew)
        buildProcess.arguments = [":app:assembleDebug"]
        buildProcess.currentDirectoryURL = URL(fileURLWithPath: androidDir)
        let pipe = Pipe()
        buildProcess.standardOutput = pipe
        buildProcess.standardError = pipe
        try buildProcess.run()
        buildProcess.waitUntilExit()
        if buildProcess.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw SimulatorError.commandFailed(
                command: "gradlew :app:assembleDebug", output: output)
        }
        print("   ✓ Build succeeded")

        let apkPath = "\(androidDir)/app/build/outputs/apk/debug/app-debug.apk"
        guard FileManager.default.fileExists(atPath: apkPath) else {
            throw SimulatorError.appNotFound
        }

        print("   Installing APK...")
        try runProcess("/usr/bin/env", arguments: ["adb", "install", "-r", apkPath])
        print("   ✓ Installed")

        print("   Launching app...")
        try runProcess(
            "/usr/bin/env",
            arguments: [
                "adb", "shell", "am", "start",
                "-n", "\(project.bundleId)/.MainActivity",
            ])
        print("   ✓ Launched on Android emulator/device")
    }

    private func findBuiltDeviceApp(derivedDataPath: String) throws -> String {
        let buildDir = "\(derivedDataPath)/Build/Products"
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: buildDir) else {
            throw SimulatorError.appNotFound
        }
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".app") && path.contains("Debug-iphoneos") {
                return "\(buildDir)/\(path)"
            }
        }
        throw SimulatorError.appNotFound
    }

    private func findConnectedDeviceUDID() throws -> String {
        let output = try runProcess(
            "/usr/bin/xcrun",
            arguments: [
                "devicectl", "list", "devices",
            ])
        let lines = output.components(separatedBy: "\n")
        let uuidPattern = try NSRegularExpression(
            pattern: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
        )
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = uuidPattern.firstMatch(in: line, range: range) {
                let udid = (line as NSString).substring(with: match.range)
                return udid
            }
        }
        throw SimulatorError.commandFailed(
            command: "xcrun devicectl list devices",
            output: "No connected iOS device found. Connect a device via USB and try again."
        )
    }

    private func findBuiltApp(derivedDataPath: String) throws -> String {
        let buildDir = "\(derivedDataPath)/Build/Products"
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: buildDir) else {
            throw SimulatorError.appNotFound
        }
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".app") && path.contains("Debug-iphonesimulator") {
                return "\(buildDir)/\(path)"
            }
        }
        throw SimulatorError.appNotFound
    }

    @discardableResult
    private func runProcess(_ launchPath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw SimulatorError.commandFailed(
                command: ([launchPath] + arguments).joined(separator: " "),
                output: output
            )
        }
        return output
    }

    @discardableResult
    private func runProcessOptional(_ launchPath: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}

// MARK: - Platform Enum

/// Target platform for the dev preview: macOS, iOS, or Android.
enum Platform: String, ExpressibleByArgument, CaseIterable {
    case macos
    case ios
    case android
}

// MARK: - Simulator Errors

/// Errors raised when building, installing, or launching on a simulator or device.
enum SimulatorError: Error, LocalizedError {
    case projectNotFound
    case appNotFound
    case commandFailed(command: String, output: String)

    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return
                "Could not find an .xcodeproj in the project directory. Run `melody create` first."
        case .appNotFound:
            return "Could not find built .app bundle in derived data."
        case .commandFailed(let command, let output):
            return "Command failed: \(command)\n\(output)"
        }
    }
}

// MARK: - Manual Reload (stdin)

private func listenForManualReload(
    path: String, parser: AppParser, server: DevWebSocketServer, isDir: Bool = false
) {
    DispatchQueue.global(qos: .utility).async {
        while let line = readLine() {
            if line.trimmingCharacters(in: .whitespaces).lowercased() == "r" {
                DispatchQueue.main.async {
                    doReload(
                        path: path, parser: parser, server: server, isDir: isDir,
                        changedFile: "manual")
                }
            }
        }
    }
}

// MARK: - File Reload

private func doReload(
    path: String, parser: AppParser, server: DevWebSocketServer, isDir: Bool = false,
    changedFile: String? = nil
) {
    do {
        guard let changedFile else {
            return
        }
        let updated: AppDefinition
        let yaml: String
        if isDir {
            updated = try parser.parseDirectory(at: path)
            yaml = try parser.mergeDirectoryToYAML(at: path)
        } else {
            yaml = try String(contentsOfFile: path, encoding: .utf8)
            updated = try parser.parse(yaml)
        }
        server.broadcast(yaml: yaml, reason: changedFile)
        let reason = " (\(changedFile))"
        print("   ↻ Reloaded — \(updated.screens.count) screen(s)\(reason)")
    } catch {
        print("   ✗ \(error.localizedDescription)")
        print("   ✗ \(error)")
    }
}

// MARK: - File Watcher

private func watchFile(path: String, parser: AppParser, server: DevWebSocketServer) {
    let fd = open(path, O_EVTONLY)
    guard fd >= 0 else {
        print("   ✗ Cannot watch file: \(path)")
        return
    }

    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.write, .rename, .delete],
        queue: .main
    )

    source.setEventHandler {
        let events = source.data

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            doReload(path: path, parser: parser, server: server)
        }

        if events.contains(.rename) || events.contains(.delete) {
            source.cancel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                watchFile(path: path, parser: parser, server: server)
            }
        }
    }

    source.setCancelHandler {
        close(fd)
    }

    source.resume()
}

// MARK: - Directory Watcher

nonisolated(unsafe) private var activeDirectorySources: [DispatchSourceFileSystemObject] = []

private func cancelAllDirectorySources() {
    for source in activeDirectorySources {
        source.cancel()
    }
    activeDirectorySources.removeAll()
}

nonisolated(unsafe) private var directoryReloadWork: DispatchWorkItem?
nonisolated(unsafe) private var pendingChangedFile: String?

private func scheduleDirectoryReload(
    dirPath: String, parser: AppParser, server: DevWebSocketServer, changedFile: String? = nil
) {
    directoryReloadWork?.cancel()
    if let changedFile { pendingChangedFile = changedFile }
    let work = DispatchWorkItem {
        let reason = pendingChangedFile
        pendingChangedFile = nil
        doReload(path: dirPath, parser: parser, server: server, isDir: true, changedFile: reason)
        cancelAllDirectorySources()
        watchDirectory(path: dirPath, parser: parser, server: server)
    }
    directoryReloadWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
}

private func watchDirectory(path: String, parser: AppParser, server: DevWebSocketServer) {
    let appFile = (path as NSString).appendingPathComponent("app.yaml")

    watchFileForDirectory(filePath: appFile, dirPath: path, parser: parser, server: server)

    let screenFiles = AppParser.findYAMLFiles(in: path, excluding: "app.yaml")
    for filePath in screenFiles {
        watchFileForDirectory(filePath: filePath, dirPath: path, parser: parser, server: server)
    }

    watchSubdirectories(dirPath: path, parser: parser, server: server)
}

private func watchFileForDirectory(
    filePath: String, dirPath: String, parser: AppParser, server: DevWebSocketServer
) {
    let fd = open(filePath, O_EVTONLY)
    guard fd >= 0 else { return }

    let relativePath =
        filePath.hasPrefix(dirPath)
        ? String(filePath.dropFirst(dirPath.count).drop(while: { $0 == "/" }))
        : (filePath as NSString).lastPathComponent

    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.write, .rename, .delete],
        queue: .main
    )

    source.setEventHandler { [source] in
        let events = source.data

        scheduleDirectoryReload(
            dirPath: dirPath, parser: parser, server: server, changedFile: relativePath)

        if events.contains(.rename) || events.contains(.delete) {
            source.cancel()
        }
    }

    source.setCancelHandler { close(fd) }
    source.resume()
    activeDirectorySources.append(source)
}

private func watchSubdirectories(dirPath: String, parser: AppParser, server: DevWebSocketServer) {
    let fm = FileManager.default

    watchSingleSubdirectory(subdirPath: dirPath, dirPath: dirPath, parser: parser, server: server)

    guard let enumerator = fm.enumerator(atPath: dirPath) else { return }

    var subdirs: [String] = []
    while let relative = enumerator.nextObject() as? String {
        let fullPath = (dirPath as NSString).appendingPathComponent(relative)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
            if !(relative as NSString).lastPathComponent.hasPrefix(".") {
                subdirs.append(fullPath)
            }
        }
    }

    for subdir in subdirs {
        watchSingleSubdirectory(
            subdirPath: subdir, dirPath: dirPath, parser: parser, server: server)
    }
}

private func watchSingleSubdirectory(
    subdirPath: String, dirPath: String, parser: AppParser, server: DevWebSocketServer
) {
    let fd = open(subdirPath, O_EVTONLY)
    guard fd >= 0 else { return }

    let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: fd,
        eventMask: [.write, .rename],
        queue: .main
    )

    source.setEventHandler {
        scheduleDirectoryReload(dirPath: dirPath, parser: parser, server: server)
    }

    source.setCancelHandler { close(fd) }
    source.resume()
    activeDirectorySources.append(source)
}
