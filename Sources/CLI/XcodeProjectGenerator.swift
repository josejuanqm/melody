import Foundation
import Core

/// Generates a complete `.xcodeproj` and supporting files for a Melody project.
struct XcodeProjectGenerator {

    static func generate(
        name: String,
        bundleId: String,
        projectDir: String,
        melodyVersion: String,
        widgets: [String: WidgetDefinition]? = nil,
        widgetYAMLContents: [String: String]? = nil
    ) throws {
        let fm = FileManager.default
        let hasWidgets = !(widgets ?? [:]).isEmpty

        let xcodeprojDir = (projectDir as NSString).appendingPathComponent("\(name).xcodeproj")
        let assetsDir = (projectDir as NSString).appendingPathComponent(
            "Assets.xcassets/AppIcon.appiconset")
        try fm.createDirectory(atPath: xcodeprojDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)

        try generatePbxproj(name: name, melodyVersion: melodyVersion, widgets: widgets)
            .write(
                toFile: (xcodeprojDir as NSString).appendingPathComponent("project.pbxproj"),
                atomically: true, encoding: .utf8)
        try generateAppSwift(name: name, bundleId: bundleId, hasWidgets: hasWidgets)
            .write(
                toFile: (projectDir as NSString).appendingPathComponent("App.swift"),
                atomically: true, encoding: .utf8)
        try generateDevConfig()
            .write(
                toFile: (projectDir as NSString).appendingPathComponent("DevConfig.swift"),
                atomically: true, encoding: .utf8)
        try generateManifest(name: name, bundleId: bundleId)
            .write(
                toFile: (projectDir as NSString).appendingPathComponent("Manifest.xcconfig"),
                atomically: true, encoding: .utf8)
        try generateInfoPlist()
            .write(
                toFile: (projectDir as NSString).appendingPathComponent("Info.plist"),
                atomically: true, encoding: .utf8)
        try generateAppIconContents()
            .write(
                toFile: (assetsDir as NSString).appendingPathComponent("Contents.json"),
                atomically: true, encoding: .utf8)

        if hasWidgets {
            let widgetExtDir = (projectDir as NSString).appendingPathComponent("\(name)Widgets")
            try fm.createDirectory(atPath: widgetExtDir, withIntermediateDirectories: true)

            try generateWidgetBundleSwift(name: name, widgets: widgets!)
                .write(
                    toFile: (widgetExtDir as NSString).appendingPathComponent("WidgetBundle.swift"),
                    atomically: true, encoding: .utf8)

            for (_, widget) in widgets! {
                let widgetName = widgetSwiftName(widget.id)
                let yamlContent = widgetYAMLContents?[widget.id]
                try generateWidgetSwift(name: name, bundleId: bundleId, widget: widget, yamlContent: yamlContent)
                    .write(
                        toFile: (widgetExtDir as NSString).appendingPathComponent("\(widgetName)Widget.swift"),
                        atomically: true, encoding: .utf8)
            }

            try generateEntitlements(bundleId: bundleId)
                .write(
                    toFile: (projectDir as NSString).appendingPathComponent("\(name).entitlements"),
                    atomically: true, encoding: .utf8)
            try generateEntitlements(bundleId: bundleId)
                .write(
                    toFile: (widgetExtDir as NSString).appendingPathComponent("\(name)Widgets.entitlements"),
                    atomically: true, encoding: .utf8)
            try generateWidgetInfoPlist()
                .write(
                    toFile: (widgetExtDir as NSString).appendingPathComponent("Info.plist"),
                    atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Widget file generators

    private static func widgetSwiftName(_ id: String) -> String {
        id.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
            .split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private static func generateWidgetBundleSwift(name: String, widgets: [String: WidgetDefinition]) -> String {
        let widgetEntries = widgets.keys.sorted().map { widgetSwiftName($0) + "Widget()" }.joined(separator: "\n        ")
        return """
            import WidgetKit
            import SwiftUI

            @main
            struct \(name)WidgetBundle: WidgetBundle {
                var body: some Widget {
                    \(widgetEntries)
                }
            }
            """
    }

    private static func generateWidgetSwift(name: String, bundleId: String, widget: WidgetDefinition, yamlContent: String? = nil) -> String {
        let swiftName = widgetSwiftName(widget.id)
        let families = widget.families.map { family -> String in
            switch family {
            case .small: return ".systemSmall"
            case .medium: return ".systemMedium"
            case .large: return ".systemLarge"
            }
        }
        let familiesStr = families.isEmpty ? ".systemSmall, .systemMedium" : families.joined(separator: ", ")
        let widgetDescription = widget.description ?? widget.name ?? widget.id

        let embeddedYAML: String
        if let yamlContent {
            embeddedYAML = yamlContent.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"\"\"", with: "\\\"\\\"\\\"")
        } else {
            embeddedYAML = "WIDGET_YAML_CONTENT"
        }

        let hasConfigure = widget.configure != nil
        let imports = hasConfigure
            ? "import WidgetKit\n    import SwiftUI\n    import AppIntents\n    import Widgets\n    import Core"
            : "import WidgetKit\n    import SwiftUI\n    import Widgets\n    import Core"

        let suiteName = "group.\(bundleId)"

        if hasConfigure {
            // Parameter-based: generate a placeholder that references the generated intent.
            // Full generation is handled by GenerateWidgetsCommand; XcodeProjectGenerator
            // provides a minimal version for project scaffolding.
            return """
                \(imports)

                struct \(swiftName)Widget: Widget {
                    let kind: String = "\(widget.id)"
                    static let appLuaPrelude: String? = nil

                    private let widgetYAML = \"\"\"
                \(embeddedYAML)
                \"\"\"

                    var body: some WidgetConfiguration {
                        StaticConfiguration(kind: kind, provider: MelodyTimelineProvider(widgetYAML: widgetYAML, suiteName: "\(suiteName)")) { entry in
                            MelodyWidgetView(entry: entry)
                        }
                        .configurationDisplayName("\(widget.name ?? widget.id)")
                        .description("\(widgetDescription)")
                        .supportedFamilies([\(familiesStr)])
                    }
                }
                """
        }

        return """
            \(imports)

            struct \(swiftName)Widget: Widget {
                let kind: String = "\(widget.id)"

                private let widgetYAML = \"\"\"
            \(embeddedYAML)
            \"\"\"

                var body: some WidgetConfiguration {
                    StaticConfiguration(kind: kind, provider: MelodyTimelineProvider(widgetYAML: widgetYAML, suiteName: "\(suiteName)")) { entry in
                        MelodyWidgetView(entry: entry)
                    }
                    .configurationDisplayName("\(widget.name ?? widget.id)")
                    .description("\(widgetDescription)")
                    .supportedFamilies([\(familiesStr)])
                }
            }
            """
    }

    private static func generateEntitlements(bundleId: String) -> String {
        return """
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
    }

    private static func generateWidgetInfoPlist() -> String {
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            \t<key>NSExtension</key>
            \t<dict>
            \t\t<key>NSExtensionPointIdentifier</key>
            \t\t<string>com.apple.widgetkit-extension</string>
            \t</dict>
            </dict>
            </plist>
            """
    }

    // MARK: - Templates

    private static func generateAppSwift(name: String, bundleId: String = "", hasWidgets: Bool = false) -> String {
        let storeInit = hasWidgets
            ? "MelodyStore(suiteName: \"group.\(bundleId)\")"
            : "MelodyStore()"
        return """
            import SwiftUI
            #if canImport(AppKit)
            import AppKit
            #endif
            #if canImport(UIKit)
            import UIKit
            #endif
            import Runtime
            import Core

            /// Plugins registered for this app. Replaced by generated code when plugins are installed.
            let melodyPlugins: [MelodyPlugin] = []

            @main
            struct \(name)App: App {
                @State private var appDefinition: AppDefinition?
                @State private var error: String?
                #if MELODY_DEV
                @State private var hotReload = HotReloadClient()
                #endif

                var body: some Scene {
                    WindowGroup {
                        Group {
                            if let app = appDefinition {
                                #if MELODY_DEV
                                MelodyAppView(appDefinition: app, plugins: melodyPlugins, assetBaseURL: "http://\\(melodyDevHost):\\(melodyDevAssetPort)", store: \(storeInit))
                                #else
                                MelodyAppView(appDefinition: app, plugins: melodyPlugins, store: \(storeInit))
                                #endif
                            } else if let error = error {
                                errorView(error)
                            } else {
                                splashView
                                    .task { loadApp() }
                            }
                        }
                        #if MELODY_DEV
                        .onAppear { hotReload.connect(host: melodyDevHost, port: melodyDevPort) }
                        .onChange(of: hotReload.reloadCount) { _, _ in
                            if let newApp = hotReload.latestApp {
                                appDefinition = newApp
                                error = nil
                            }
                        }
                        #endif
                    }
                }

                @ViewBuilder
                private var splashView: some View {
                    ZStack {
                        #if canImport(AppKit)
                        Color(NSColor.windowBackgroundColor).ignoresSafeArea()
                        #endif
                        #if canImport(UIKit)
                        Color(UIColor.systemBackground).ignoresSafeArea()
                        #endif
                        if let image = loadAppIcon() {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                        }
                    }
                }

                private func loadAppIcon() -> Image? {
                    guard let url = Bundle.main.url(forResource: "icon", withExtension: "png"),
                          let data = try? Data(contentsOf: url) else { return nil }
                    #if os(macOS)
                    guard let nsImage = NSImage(data: data) else { return nil }
                    return Image(nsImage: nsImage)
                    #else
                    guard let uiImage = UIImage(data: data) else { return nil }
                    return Image(uiImage: uiImage)
                    #endif
                }

                private func loadApp() {
                    let parser = AppParser()
                    do {
                        if let url = Bundle.main.url(forResource: "app", withExtension: "yaml") {
                            let dirPath = url.deletingLastPathComponent().path
                            appDefinition = try parser.parseDirectory(at: dirPath)
                        } else {
                            throw NSError(domain: "Melody", code: 1,
                                          userInfo: [NSLocalizedDescriptionKey: "app.yaml not found in bundle"])
                        }
                    } catch {
                        #if MELODY_DEV
                        print("[Melody] File load failed, waiting for dev server: \\(error.localizedDescription)")
                        #else
                        self.error = error.localizedDescription
                        #endif
                    }
                }

                @ViewBuilder
                private func errorView(_ message: String) -> some View {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                        Text("Failed to load app")
                            .font(.title2.bold())
                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            """
    }

    private static func generateDevConfig() -> String {
        return """
            #if MELODY_DEV
            let melodyDevHost = "localhost"
            let melodyDevPort = 8375
            let melodyDevAssetPort = 8376
            #endif
            """
    }

    private static func generateManifest(name: String, bundleId: String) -> String {
        return """
            // App manifest — values from app.yaml
            // Regenerate: grep name/id from app.yaml or update manually

            MELODY_APP_NAME = \(name)
            MELODY_BUNDLE_ID = \(bundleId)
            """
    }

    private static func generateInfoPlist() -> String {
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
            \t<key>LSApplicationCategoryType</key>
            \t<string>public.app-category.developer-tools</string>
            \t<key>NSAppTransportSecurity</key>
            \t<dict>
            \t\t<key>NSAllowsArbitraryLoads</key>
            \t\t<true/>
            \t</dict>
            </dict>
            </plist>
            """
    }

    private static func generateAppIconContents() -> String {
        return """
            {
              "images" : [
                {
                  "filename" : "icon.png",
                  "idiom" : "universal",
                  "platform" : "ios",
                  "size" : "1024x1024"
                },
                {
                  "filename" : "icon.png",
                  "idiom" : "mac",
                  "size" : "512x512"
                },
                {
                  "filename" : "icon.png",
                  "idiom" : "mac",
                  "size" : "256x256"
                },
                {
                  "filename" : "icon.png",
                  "idiom" : "mac",
                  "size" : "128x128"
                },
                {
                  "filename" : "icon.png",
                  "idiom" : "mac",
                  "size" : "64x64"
                },
                {
                  "filename" : "icon.png",
                  "idiom" : "mac",
                  "size" : "32x32"
                },
                {
                  "filename" : "icon.png",
                  "idiom" : "mac",
                  "size" : "16x16"
                }
              ],
              "info" : {
                "author" : "xcode",
                "version" : 1
              }
            }
            """
    }

    // MARK: - pbxproj

    private static func pbxprojEscape(_ s: String) -> String {
        var result = ""
        result.reserveCapacity(s.count)
        for char in s {
            switch char {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\t": result += "\\t"
            default: result += String(char)
            }
        }
        return result
    }

    private static let macOSIconScript = """
        if [ "$PLATFORM_NAME" != "macosx" ]; then
          exit 0
        fi

        ICON_SRC="${SRCROOT}/icon.png"
        if [ ! -f "$ICON_SRC" ]; then
          echo "warning: icon.png not found"
          exit 0
        fi

        ICONSET_DIR="${DERIVED_FILE_DIR}/AppIcon.iconset"
        rm -rf "$ICONSET_DIR"
        mkdir -p "$ICONSET_DIR"

        sips -z 16 16     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
        sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
        sips -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
        sips -z 64 64     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
        sips -z 128 128   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
        sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
        sips -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
        sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
        sips -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
        sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

        iconutil -c icns "$ICONSET_DIR" -o "${DERIVED_FILE_DIR}/AppIcon.icns"

        RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
        mkdir -p "$RESOURCES_DIR"
        cp "${DERIVED_FILE_DIR}/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
        """

    private static let generateWidgetsScript = """
        if ! command -v melody &> /dev/null; then
          echo "warning: melody CLI not found in PATH, skipping widget generation"
          exit 0
        fi

        melody generate-widgets -f "${SRCROOT}" -o "${SRCROOT}/${TARGET_NAME}"
        """

    private static func generatePbxproj(name: String, melodyVersion: String, widgets: [String: WidgetDefinition]? = nil) -> String {
        let shellScript = pbxprojEscape(macOSIconScript)
        let hasWidgets = !(widgets ?? [:]).isEmpty
        let sortedWidgetIds = (widgets ?? [:]).keys.sorted()

        var widgetBuildFiles = ""
        var widgetFileRefs = ""
        var widgetSourceFiles = ""
        var widgetGroupChildren = ""
        var widgetPackageDeps = ""

        if hasWidgets {
            widgetBuildFiles = """

            \t\tC1000001 /* WidgetBundle.swift in Sources */ = {isa = PBXBuildFile; fileRef = C2000001 /* WidgetBundle.swift */; };
            \t\tC1000002 /* Widgets in Frameworks */ = {isa = PBXBuildFile; productRef = C4000001 /* Widgets */; };
            \t\tC1000003 /* Core in Frameworks */ = {isa = PBXBuildFile; productRef = C4000002 /* Core */; };
            """
            widgetFileRefs = """

            \t\tC2000001 /* WidgetBundle.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WidgetBundle.swift; sourceTree = \"<group>\"; };
            \t\tC2000002 /* \(name)Widgets.appex */ = {isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = \"\(name)Widgets.appex\"; sourceTree = BUILT_PRODUCTS_DIR; };
            \t\tC2000003 /* \(name).entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = \"\(name).entitlements\"; sourceTree = \"<group>\"; };
            \t\tC2000004 /* \(name)Widgets.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = \"\(name)Widgets.entitlements\"; sourceTree = \"<group>\"; };
            """
            widgetSourceFiles = "\t\t\t\tC1000001 /* WidgetBundle.swift in Sources */,\n"
            widgetGroupChildren = "\t\t\t\tC2000001 /* WidgetBundle.swift */,\n"

            for (index, widgetId) in sortedWidgetIds.enumerated() {
                let swiftName = widgetSwiftName(widgetId)
                let fileIdx = String(format: "%04d", index + 5)
                let buildIdx = String(format: "%04d", index + 4)
                widgetBuildFiles += "\t\tC1\(buildIdx) /* \(swiftName)Widget.swift in Sources */ = {isa = PBXBuildFile; fileRef = C2\(fileIdx) /* \(swiftName)Widget.swift */; };\n"
                widgetFileRefs += "\t\tC2\(fileIdx) /* \(swiftName)Widget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"\(swiftName)Widget.swift\"; sourceTree = \"<group>\"; };\n"
                widgetSourceFiles += "\t\t\t\tC1\(buildIdx) /* \(swiftName)Widget.swift in Sources */,\n"
                widgetGroupChildren += "\t\t\t\tC2\(fileIdx) /* \(swiftName)Widget.swift */,\n"
            }

            widgetPackageDeps = """
            \t\tC4000001 /* Widgets */ = {
            \t\t\tisa = XCSwiftPackageProductDependency;
            \t\t\tpackage = B4100001 /* XCRemoteSwiftPackageReference "melody" */;
            \t\t\tproductName = Widgets;
            \t\t};
            \t\tC4000002 /* Core */ = {
            \t\t\tisa = XCSwiftPackageProductDependency;
            \t\t\tpackage = B4100001 /* XCRemoteSwiftPackageReference "melody" */;
            \t\t\tproductName = Core;
            \t\t};
            """
        }

        let mainAppDeps = hasWidgets ? "\t\t\t\tC9000001 /* PBXTargetDependency */," : ""
        let mainAppBuildPhases = hasWidgets ? "\t\t\t\tC3000001 /* Embed App Extensions */," : ""
        let mainGroupEntitlements = hasWidgets ? "\t\t\t\tC2000003 /* \(name).entitlements */," : ""
        let mainGroupWidgetDir = hasWidgets ? "\t\t\t\tC5000001 /* \(name)Widgets */," : ""
        let productsWidgetAppex = hasWidgets ? "\t\t\t\tC2000002 /* \(name)Widgets.appex */," : ""
        let targetsList = hasWidgets ? "\t\t\t\tB6000001 /* \(name) */,\n\t\t\t\tC6000001 /* \(name)Widgets */," : "\t\t\t\tB6000001 /* \(name) */,"
        let targetAttributes = hasWidgets ? """
        \t\t\t\t\tB6000001 = {
        \t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
        \t\t\t\t\t};
        \t\t\t\t\tC6000001 = {
        \t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
        \t\t\t\t\t};
        """ : """
        \t\t\t\t\tB6000001 = {
        \t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
        \t\t\t\t\t};
        """
        let mainEntitlementSetting = hasWidgets ? "\t\t\t\tCODE_SIGN_ENTITLEMENTS = \"\(name).entitlements\";" : ""

        var widgetSections = ""
        if hasWidgets {
            widgetSections = """

            /* Begin PBXContainerItemProxy section */
            \t\tC9000002 /* PBXContainerItemProxy */ = {
            \t\t\tisa = PBXContainerItemProxy;
            \t\t\tcontainerPortal = B9000001 /* Project object */;
            \t\t\tproxyType = 1;
            \t\t\tremoteGlobalIDString = C6000001;
            \t\t\tremoteInfo = \"\(name)Widgets\";
            \t\t};
            /* End PBXContainerItemProxy section */

            /* Begin PBXCopyFilesBuildPhase section */
            \t\tC3000001 /* Embed App Extensions */ = {
            \t\t\tisa = PBXCopyFilesBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tdstPath = \"\";
            \t\t\tdstSubfolderSpec = 13;
            \t\t\tfiles = (
            \t\t\t\tC1000010 /* \(name)Widgets.appex in Embed App Extensions */,
            \t\t\t);
            \t\t\tname = \"Embed App Extensions\";
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t};
            /* End PBXCopyFilesBuildPhase section */

            /* Begin PBXTargetDependency section */
            \t\tC9000001 /* PBXTargetDependency */ = {
            \t\t\tisa = PBXTargetDependency;
            \t\t\ttarget = C6000001 /* \(name)Widgets */;
            \t\t\ttargetProxy = C9000002 /* PBXContainerItemProxy */;
            \t\t};
            /* End PBXTargetDependency section */
            """
        }

        var widgetNativeTarget = ""
        var widgetFrameworksPhase = ""
        var widgetSourcesPhase = ""
        var widgetResourcesPhase = ""
        var widgetGenerateScriptPhase = ""
        var widgetBuildConfigs = ""
        var widgetConfigList = ""
        var widgetGroup = ""
        var widgetBuildFileEmbed = ""

        if hasWidgets {
            widgetBuildFileEmbed = "\t\tC1000010 /* \(name)Widgets.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = C2000002 /* \(name)Widgets.appex */; platformFilters = (ios, xros, ); settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n"

            widgetFrameworksPhase = """
            \t\tC3000002 /* Frameworks */ = {
            \t\t\tisa = PBXFrameworksBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t\tC1000002 /* Widgets in Frameworks */,
            \t\t\t\tC1000003 /* Core in Frameworks */,
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t};
            """

            widgetSourcesPhase = """
            \t\tC7000001 /* Sources */ = {
            \t\t\tisa = PBXSourcesBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \(widgetSourceFiles)\t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t};
            """

            widgetResourcesPhase = """
            \t\tC3000003 /* Resources */ = {
            \t\t\tisa = PBXResourcesBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t};
            """

            let widgetScript = pbxprojEscape(generateWidgetsScript)
            widgetGenerateScriptPhase = """
            \t\tC7000002 /* Generate Widgets */ = {
            \t\t\tisa = PBXShellScriptBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t);
            \t\t\tinputPaths = (
            \t\t\t\t\"$(SRCROOT)/widgets/\",
            \t\t\t);
            \t\t\tname = \"Generate Widgets\";
            \t\t\toutputPaths = (
            \t\t\t\t\"$(SRCROOT)/\(name)Widgets/WidgetBundle.swift\",
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t\tshellPath = /bin/sh;
            \t\t\tshellScript = \"\(widgetScript)\";
            \t\t};
            """

            widgetNativeTarget = """
            \t\tC6000001 /* \(name)Widgets */ = {
            \t\t\tisa = PBXNativeTarget;
            \t\t\tbuildConfigurationList = C8000003 /* Build configuration list for PBXNativeTarget \"\(name)Widgets\" */;
            \t\t\tbuildPhases = (
            \t\t\t\tC7000002 /* Generate Widgets */,
            \t\t\t\tC7000001 /* Sources */,
            \t\t\t\tC3000002 /* Frameworks */,
            \t\t\t\tC3000003 /* Resources */,
            \t\t\t);
            \t\t\tbuildRules = (
            \t\t\t);
            \t\t\tdependencies = (
            \t\t\t);
            \t\t\tname = \"\(name)Widgets\";
            \t\t\tpackageProductDependencies = (
            \t\t\t\tC4000001 /* Widgets */,
            \t\t\t\tC4000002 /* Core */,
            \t\t\t);
            \t\t\tproductName = \"\(name)Widgets\";
            \t\t\tproductReference = C2000002 /* \(name)Widgets.appex */;
            \t\t\tproductType = \"com.apple.product-type.app-extension\";
            \t\t};
            """

            widgetGroup = """
            \t\tC5000001 /* \(name)Widgets */ = {
            \t\t\tisa = PBXGroup;
            \t\t\tchildren = (
            \t\t\t\tC2000004 /* \(name)Widgets.entitlements */,
            \(widgetGroupChildren)\t\t\t);
            \t\t\tpath = \"\(name)Widgets\";
            \t\t\tsourceTree = \"<group>\";
            \t\t};
            """

            widgetBuildConfigs = """
            \t\tC8000021 /* Debug */ = {
            \t\t\tisa = XCBuildConfiguration;
            \t\t\tbaseConfigurationReference = B2000005 /* Manifest.xcconfig */;
            \t\t\tbuildSettings = {
            \t\t\t\tCODE_SIGN_ENTITLEMENTS = \"\(name)Widgets/\(name)Widgets.entitlements\";
            \t\t\t\tCODE_SIGN_STYLE = Automatic;
            \t\t\t\tCURRENT_PROJECT_VERSION = 1;
            \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
            \t\t\t\tINFOPLIST_FILE = \"\(name)Widgets/Info.plist\";
            \t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"\(name) Widgets\";
            \t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = \"\";
            \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
            \t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
            \t\t\t\t\t\"$(inherited)\",
            \t\t\t\t\t\"@executable_path/Frameworks\",
            \t\t\t\t\t\"@executable_path/../../Frameworks\",
            \t\t\t\t);
            \t\t\t\tMARKETING_VERSION = 1.0;
            \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"$(MELODY_BUNDLE_ID).widgets\";
            \t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
            \t\t\t\tSKIP_INSTALL = YES;
            \t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator xros xrsimulator\";
            \t\t\t\tSUPPORTS_MACCATALYST = NO;
            \t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
            \t\t\t\tSWIFT_VERSION = 5.0;
            \t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2,7\";
            \t\t\t};
            \t\t\tname = Debug;
            \t\t};
            \t\tC8000022 /* Release */ = {
            \t\t\tisa = XCBuildConfiguration;
            \t\t\tbaseConfigurationReference = B2000005 /* Manifest.xcconfig */;
            \t\t\tbuildSettings = {
            \t\t\t\tCODE_SIGN_ENTITLEMENTS = \"\(name)Widgets/\(name)Widgets.entitlements\";
            \t\t\t\tCODE_SIGN_STYLE = Automatic;
            \t\t\t\tCURRENT_PROJECT_VERSION = 1;
            \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
            \t\t\t\tINFOPLIST_FILE = \"\(name)Widgets/Info.plist\";
            \t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"\(name) Widgets\";
            \t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = \"\";
            \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
            \t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
            \t\t\t\t\t\"$(inherited)\",
            \t\t\t\t\t\"@executable_path/Frameworks\",
            \t\t\t\t\t\"@executable_path/../../Frameworks\",
            \t\t\t\t);
            \t\t\t\tMARKETING_VERSION = 1.0;
            \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"$(MELODY_BUNDLE_ID).widgets\";
            \t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";
            \t\t\t\tSKIP_INSTALL = YES;
            \t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator xros xrsimulator\";
            \t\t\t\tSUPPORTS_MACCATALYST = NO;
            \t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
            \t\t\t\tSWIFT_VERSION = 5.0;
            \t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2,7\";
            \t\t\t};
            \t\t\tname = Release;
            \t\t};
            """

            widgetConfigList = """
            \t\tC8000003 /* Build configuration list for PBXNativeTarget \"\(name)Widgets\" */ = {
            \t\t\tisa = XCConfigurationList;
            \t\t\tbuildConfigurations = (
            \t\t\t\tC8000021 /* Debug */,
            \t\t\t\tC8000022 /* Release */,
            \t\t\t);
            \t\t\tdefaultConfigurationIsVisible = 0;
            \t\t\tdefaultConfigurationName = Release;
            \t\t};
            """
        }

        return """
            // !$*UTF8*$!
            {
            \tarchiveVersion = 1;
            \tclasses = {
            \t};
            \tobjectVersion = 56;
            \tobjects = {

            /* Begin PBXBuildFile section */
            \t\tB1000001 /* App.swift in Sources */ = {isa = PBXBuildFile; fileRef = B2000001 /* App.swift */; };
            \t\tB1000002 /* Runtime in Frameworks */ = {isa = PBXBuildFile; productRef = B4000001 /* Runtime */; };
            \t\tB1000003 /* Core in Frameworks */ = {isa = PBXBuildFile; productRef = B4000002 /* Core */; };
            \t\tB1000004 /* DevConfig.swift in Sources */ = {isa = PBXBuildFile; fileRef = B2000004 /* DevConfig.swift */; };
            \t\tB1000005 /* app.yaml in Resources */ = {isa = PBXBuildFile; fileRef = B2000007 /* app.yaml */; };
            \t\tB1000006 /* screens in Resources */ = {isa = PBXBuildFile; fileRef = B2000008 /* screens */; };
            \t\tB1000007 /* components in Resources */ = {isa = PBXBuildFile; fileRef = B2000009 /* components */; };
            \t\tB1000008 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = B2000010 /* Assets.xcassets */; };
            \t\tB1000009 /* assets in Resources */ = {isa = PBXBuildFile; fileRef = B2000011 /* assets */; };
            \(widgetBuildFiles)\(widgetBuildFileEmbed)/* End PBXBuildFile section */

            /* Begin PBXFileReference section */
            \t\tB2000001 /* App.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = \"<group>\"; };
            \t\tB2000002 /* \(name).app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"\(name).app\"; sourceTree = BUILT_PRODUCTS_DIR; };
            \t\tB2000004 /* DevConfig.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DevConfig.swift; sourceTree = \"<group>\"; };
            \t\tB2000005 /* Manifest.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Manifest.xcconfig; sourceTree = \"<group>\"; };
            \t\tB2000006 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist; path = Info.plist; sourceTree = \"<group>\"; };
            \t\tB2000007 /* app.yaml */ = {isa = PBXFileReference; lastKnownFileType = text.yaml; path = app.yaml; sourceTree = \"<group>\"; };
            \t\tB2000008 /* screens */ = {isa = PBXFileReference; lastKnownFileType = folder; path = screens; sourceTree = \"<group>\"; };
            \t\tB2000009 /* components */ = {isa = PBXFileReference; lastKnownFileType = folder; path = components; sourceTree = \"<group>\"; };
            \t\tB2000010 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; };
            \t\tB2000011 /* assets */ = {isa = PBXFileReference; lastKnownFileType = folder; path = assets; sourceTree = \"<group>\"; };
            \(widgetFileRefs)/* End PBXFileReference section */

            /* Begin PBXFrameworksBuildPhase section */
            \t\tB3000001 /* Frameworks */ = {
            \t\t\tisa = PBXFrameworksBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t\tB1000002 /* Runtime in Frameworks */,
            \t\t\t\tB1000003 /* Core in Frameworks */,
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t};
            \(widgetFrameworksPhase)/* End PBXFrameworksBuildPhase section */

            /* Begin PBXGroup section */
            \t\tB5000001 = {
            \t\t\tisa = PBXGroup;
            \t\t\tchildren = (
            \t\t\t\tB2000006 /* Info.plist */,
            \t\t\t\tB2000005 /* Manifest.xcconfig */,
            \(mainGroupEntitlements)\t\t\t\tB2000001 /* App.swift */,
            \t\t\t\tB2000004 /* DevConfig.swift */,
            \t\t\t\tB2000007 /* app.yaml */,
            \t\t\t\tB2000008 /* screens */,
            \t\t\t\tB2000009 /* components */,
            \t\t\t\tB2000010 /* Assets.xcassets */,
            \t\t\t\tB2000011 /* assets */,
            \(mainGroupWidgetDir)\t\t\t\tB5000002 /* Products */,
            \t\t\t);
            \t\t\tsourceTree = \"<group>\";
            \t\t};
            \t\tB5000002 /* Products */ = {
            \t\t\tisa = PBXGroup;
            \t\t\tchildren = (
            \t\t\t\tB2000002 /* \(name).app */,
            \(productsWidgetAppex)\t\t\t);
            \t\t\tname = Products;
            \t\t\tsourceTree = \"<group>\";
            \t\t};
            \(widgetGroup)/* End PBXGroup section */

            /* Begin PBXNativeTarget section */
            \t\tB6000001 /* \(name) */ = {
            \t\t\tisa = PBXNativeTarget;
            \t\t\tbuildConfigurationList = B8000003 /* Build configuration list for PBXNativeTarget \"\(name)\" */;
            \t\t\tbuildPhases = (
            \t\t\t\tB7000001 /* Sources */,
            \t\t\t\tB3000001 /* Frameworks */,
            \t\t\t\tB3000002 /* Resources */,
            \t\t\t\tB3000003 /* Generate macOS Icon */,
            \(mainAppBuildPhases)\t\t\t);
            \t\t\tbuildRules = (
            \t\t\t);
            \t\t\tdependencies = (
            \(mainAppDeps)\t\t\t);
            \t\t\tname = \(name);
            \t\t\tpackageProductDependencies = (
            \t\t\t\tB4000001 /* Runtime */,
            \t\t\t\tB4000002 /* Core */,
            \t\t\t);
            \t\t\tproductName = \(name);
            \t\t\tproductReference = B2000002 /* \(name).app */;
            \t\t\tproductType = \"com.apple.product-type.application\";
            \t\t};
            \(widgetNativeTarget)/* End PBXNativeTarget section */

            /* Begin PBXProject section */
            \t\tB9000001 /* Project object */ = {
            \t\t\tisa = PBXProject;
            \t\t\tattributes = {
            \t\t\t\tBuildIndependentTargetsInParallel = 1;
            \t\t\t\tLastSwiftUpdateCheck = 1540;
            \t\t\t\tLastUpgradeCheck = 1540;
            \t\t\t\tTargetAttributes = {
            \(targetAttributes)
            \t\t\t\t};
            \t\t\t};
            \t\t\tbuildConfigurationList = B8000001 /* Build configuration list for PBXProject \"\(name)\" */;
            \t\t\tcompatibilityVersion = \"Xcode 14.0\";
            \t\t\tdevelopmentRegion = en;
            \t\t\thasScannedForEncodings = 0;
            \t\t\tknownRegions = (
            \t\t\t\ten,
            \t\t\t\tBase,
            \t\t\t);
            \t\t\tmainGroup = B5000001;
            \t\t\tpackageReferences = (
            \t\t\t\tB4100001 /* XCRemoteSwiftPackageReference "melody" */,
            \t\t\t);
            \t\t\tproductRefGroup = B5000002 /* Products */;
            \t\t\tprojectDirPath = \"\";
            \t\t\tprojectRoot = \"\";
            \t\t\ttargets = (
            \(targetsList)
            \t\t\t);
            \t\t};
            /* End PBXProject section */

            /* Begin PBXResourcesBuildPhase section */
            \t\tB3000002 /* Resources */ = {
            \t\t\tisa = PBXResourcesBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t\tB1000005 /* app.yaml in Resources */,
            \t\t\t\tB1000006 /* screens in Resources */,
            \t\t\t\tB1000007 /* components in Resources */,
            \t\t\t\tB1000008 /* Assets.xcassets in Resources */,
            \t\t\t\tB1000009 /* assets in Resources */,
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t};
            \(widgetResourcesPhase)/* End PBXResourcesBuildPhase section */

            /* Begin PBXShellScriptBuildPhase section */
            \t\tB3000003 /* Generate macOS Icon */ = {
            \t\t\tisa = PBXShellScriptBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t);
            \t\t\tinputPaths = (
            \t\t\t\t\"$(SRCROOT)/icon.png\",
            \t\t\t);
            \t\t\tname = \"Generate macOS Icon\";
            \t\t\toutputPaths = (
            \t\t\t\t\"$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/AppIcon.icns\",
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t\tshellPath = /bin/sh;
            \t\t\tshellScript = \"\(shellScript)\";
            \t\t};
            \(widgetGenerateScriptPhase)/* End PBXShellScriptBuildPhase section */

            /* Begin PBXSourcesBuildPhase section */
            \t\tB7000001 /* Sources */ = {
            \t\t\tisa = PBXSourcesBuildPhase;
            \t\t\tbuildActionMask = 2147483647;
            \t\t\tfiles = (
            \t\t\t\tB1000001 /* App.swift in Sources */,
            \t\t\t\tB1000004 /* DevConfig.swift in Sources */,
            \t\t\t);
            \t\t\trunOnlyForDeploymentPostprocessing = 0;
            \t\t};
            \(widgetSourcesPhase)/* End PBXSourcesBuildPhase section */
            \(widgetSections)
            /* Begin XCBuildConfiguration section */
            \t\tB8000011 /* Debug */ = {
            \t\t\tisa = XCBuildConfiguration;
            \t\t\tbuildSettings = {
            \t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
            \t\t\t\tCLANG_ANALYZER_NONNULL = YES;
            \t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";
            \t\t\t\tCLANG_ENABLE_MODULES = YES;
            \t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
            \t\t\t\tCOPY_PHASE_STRIP = NO;
            \t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
            \t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
            \t\t\t\tENABLE_TESTABILITY = YES;
            \t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
            \t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
            \t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
            \t\t\t\t\t\"DEBUG=1\",
            \t\t\t\t\t\"$(inherited)\",
            \t\t\t\t);
            \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
            \t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
            \t\t\t\tONLY_ACTIVE_ARCH = YES;
            \t\t\t\tSDKROOT = iphoneos;
            \t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = \"$(inherited) DEBUG MELODY_DEV\";
            \t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";
            \t\t\t};
            \t\t\tname = Debug;
            \t\t};
            \t\tB8000012 /* Release */ = {
            \t\t\tisa = XCBuildConfiguration;
            \t\t\tbuildSettings = {
            \t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
            \t\t\t\tCLANG_ANALYZER_NONNULL = YES;
            \t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";
            \t\t\t\tCLANG_ENABLE_MODULES = YES;
            \t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
            \t\t\t\tCOPY_PHASE_STRIP = NO;
            \t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";
            \t\t\t\tENABLE_NS_ASSERTIONS = NO;
            \t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
            \t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
            \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
            \t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
            \t\t\t\tSDKROOT = iphoneos;
            \t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
            \t\t\t\tVALIDATE_PRODUCT = YES;
            \t\t\t};
            \t\t\tname = Release;
            \t\t};
            \t\tB8000021 /* Debug */ = {
            \t\t\tisa = XCBuildConfiguration;
            \t\t\tbaseConfigurationReference = B2000005 /* Manifest.xcconfig */;
            \t\t\tbuildSettings = {
            \t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
            \t\t\t\t\"CODE_SIGN_IDENTITY[sdk=macosx*]\" = \"-\";
            \(mainEntitlementSetting)
            \t\t\t\tCODE_SIGN_STYLE = Automatic;
            \t\t\t\tCURRENT_PROJECT_VERSION = 1;
            \t\t\t\tENABLE_APP_SANDBOX = YES;
            \t\t\t\tENABLE_HARDENED_RUNTIME = YES;
            \t\t\t\tENABLE_INCOMING_NETWORK_CONNECTIONS = YES;
            \t\t\t\tENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
            \t\t\t\tENABLE_RESOURCE_ACCESS_AUDIO_INPUT = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_BLUETOOTH = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_CALENDARS = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_CAMERA = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_CONTACTS = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_LOCATION = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_PRINTING = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_USB = NO;
            \t\t\t\tENABLE_USER_SELECTED_FILES = readwrite;
            \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
            \t\t\t\tINFOPLIST_FILE = Info.plist;
            \t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"$(MELODY_APP_NAME)\";
            \t\t\t\tINFOPLIST_KEY_CFBundleIconFile = AppIcon;
            \t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
            \t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
            \t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
            \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";
            \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";
            \t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
            \t\t\t\tMARKETING_VERSION = 1.0;
            \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"$(MELODY_BUNDLE_ID)\";
            \t\t\t\tPRODUCT_NAME = \"$(MELODY_APP_NAME)\";
            \t\t\t\tREGISTER_APP_GROUPS = YES;
            \t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";
            \t\t\t\tSUPPORTS_MACCATALYST = NO;
            \t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
            \t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
            \t\t\t\tSWIFT_VERSION = 5.0;
            \t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";
            \t\t\t};
            \t\t\tname = Debug;
            \t\t};
            \t\tB8000022 /* Release */ = {
            \t\t\tisa = XCBuildConfiguration;
            \t\t\tbaseConfigurationReference = B2000005 /* Manifest.xcconfig */;
            \t\t\tbuildSettings = {
            \t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
            \(mainEntitlementSetting)
            \t\t\t\tCODE_SIGN_STYLE = Automatic;
            \t\t\t\tCURRENT_PROJECT_VERSION = 1;
            \t\t\t\tENABLE_APP_SANDBOX = YES;
            \t\t\t\tENABLE_HARDENED_RUNTIME = YES;
            \t\t\t\tENABLE_INCOMING_NETWORK_CONNECTIONS = YES;
            \t\t\t\tENABLE_OUTGOING_NETWORK_CONNECTIONS = YES;
            \t\t\t\tENABLE_RESOURCE_ACCESS_AUDIO_INPUT = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_BLUETOOTH = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_CALENDARS = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_CAMERA = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_CONTACTS = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_LOCATION = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_PRINTING = NO;
            \t\t\t\tENABLE_RESOURCE_ACCESS_USB = NO;
            \t\t\t\tENABLE_USER_SELECTED_FILES = readwrite;
            \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
            \t\t\t\tINFOPLIST_FILE = Info.plist;
            \t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"$(MELODY_APP_NAME)\";
            \t\t\t\tINFOPLIST_KEY_CFBundleIconFile = AppIcon;
            \t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
            \t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
            \t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
            \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";
            \t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";
            \t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
            \t\t\t\tMARKETING_VERSION = 1.0;
            \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"$(MELODY_BUNDLE_ID)\";
            \t\t\t\tPRODUCT_NAME = \"$(MELODY_APP_NAME)\";
            \t\t\t\tREGISTER_APP_GROUPS = YES;
            \t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";
            \t\t\t\tSUPPORTS_MACCATALYST = NO;
            \t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
            \t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
            \t\t\t\tSWIFT_VERSION = 5.0;
            \t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";
            \t\t\t};
            \t\t\tname = Release;
            \t\t};
            \(widgetBuildConfigs)/* End XCBuildConfiguration section */

            /* Begin XCConfigurationList section */
            \t\tB8000001 /* Build configuration list for PBXProject \"\(name)\" */ = {
            \t\t\tisa = XCConfigurationList;
            \t\t\tbuildConfigurations = (
            \t\t\t\tB8000011 /* Debug */,
            \t\t\t\tB8000012 /* Release */,
            \t\t\t);
            \t\t\tdefaultConfigurationIsVisible = 0;
            \t\t\tdefaultConfigurationName = Release;
            \t\t};
            \t\tB8000003 /* Build configuration list for PBXNativeTarget \"\(name)\" */ = {
            \t\t\tisa = XCConfigurationList;
            \t\t\tbuildConfigurations = (
            \t\t\t\tB8000021 /* Debug */,
            \t\t\t\tB8000022 /* Release */,
            \t\t\t);
            \t\t\tdefaultConfigurationIsVisible = 0;
            \t\t\tdefaultConfigurationName = Release;
            \t\t};
            \(widgetConfigList)/* End XCConfigurationList section */

            /* Begin XCRemoteSwiftPackageReference section */
            \t\tB4100001 /* XCRemoteSwiftPackageReference "melody" */ = {
            \t\t\tisa = XCRemoteSwiftPackageReference;
            \t\t\trepositoryURL = \"https://github.com/josejuanqm/melody\";
            \t\t\trequirement = {
            \t\t\t\tkind = upToNextMajorVersion;
            \t\t\t\tminimumVersion = \(melodyVersion);
            \t\t\t};
            \t\t};
            /* End XCRemoteSwiftPackageReference section */

            /* Begin XCSwiftPackageProductDependency section */
            \t\tB4000001 /* Runtime */ = {
            \t\t\tisa = XCSwiftPackageProductDependency;
            \t\t\tpackage = B4100001 /* XCRemoteSwiftPackageReference "melody" */;
            \t\t\tproductName = Runtime;
            \t\t};
            \t\tB4000002 /* Core */ = {
            \t\t\tisa = XCSwiftPackageProductDependency;
            \t\t\tpackage = B4100001 /* XCRemoteSwiftPackageReference "melody" */;
            \t\t\tproductName = Core;
            \t\t};
            \(widgetPackageDeps)/* End XCSwiftPackageProductDependency section */
            \t};
            \trootObject = B9000001 /* Project object */;
            }
            """
    }
}
