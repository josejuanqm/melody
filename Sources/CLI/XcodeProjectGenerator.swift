import Foundation

/// Generates a complete `.xcodeproj` and supporting files for a Melody project.
struct XcodeProjectGenerator {

    static func generate(name: String, bundleId: String, projectDir: String, melodyPackagePath: String) throws {
        let fm = FileManager.default

        let xcodeprojDir = (projectDir as NSString).appendingPathComponent("\(name).xcodeproj")
        let assetsDir = (projectDir as NSString).appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
        try fm.createDirectory(atPath: xcodeprojDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)

        try generatePbxproj(name: name, melodyPackagePath: melodyPackagePath)
            .write(toFile: (xcodeprojDir as NSString).appendingPathComponent("project.pbxproj"),
                   atomically: true, encoding: .utf8)
        try generateAppSwift(name: name)
            .write(toFile: (projectDir as NSString).appendingPathComponent("App.swift"),
                   atomically: true, encoding: .utf8)
        try generateDevConfig()
            .write(toFile: (projectDir as NSString).appendingPathComponent("DevConfig.swift"),
                   atomically: true, encoding: .utf8)
        try generateManifest(name: name, bundleId: bundleId)
            .write(toFile: (projectDir as NSString).appendingPathComponent("Manifest.xcconfig"),
                   atomically: true, encoding: .utf8)
        try generateInfoPlist()
            .write(toFile: (projectDir as NSString).appendingPathComponent("Info.plist"),
                   atomically: true, encoding: .utf8)
        try generateAppIconContents()
            .write(toFile: (assetsDir as NSString).appendingPathComponent("Contents.json"),
                   atomically: true, encoding: .utf8)
    }

    // MARK: - Relative path helper

    static func relativePath(from base: String, to target: String) -> String {
        let baseURL = URL(fileURLWithPath: base).standardized
        let targetURL = URL(fileURLWithPath: target).standardized
        let baseComponents = baseURL.pathComponents
        let targetComponents = targetURL.pathComponents

        var commonLength = 0
        for i in 0..<min(baseComponents.count, targetComponents.count) {
            if baseComponents[i] == targetComponents[i] {
                commonLength = i + 1
            } else {
                break
            }
        }

        let ups = Array(repeating: "..", count: baseComponents.count - commonLength)
        let downs = Array(targetComponents[commonLength...])
        let components = ups + downs
        return components.isEmpty ? "." : components.joined(separator: "/")
    }

    // MARK: - Templates

    private static func generateAppSwift(name: String) -> String {
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
                            MelodyAppView(appDefinition: app, plugins: melodyPlugins, assetBaseURL: "http://\\(melodyDevHost):\\(melodyDevAssetPort)")
                            #else
                            MelodyAppView(appDefinition: app, plugins: melodyPlugins)
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

    private static func generatePbxproj(name: String, melodyPackagePath: String) -> String {
        let shellScript = pbxprojEscape(macOSIconScript)
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
        /* End PBXBuildFile section */

        /* Begin PBXFileReference section */
        \t\tB2000001 /* App.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = \"<group>\"; };
        \t\tB2000002 /* \(name).app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = \"\(name).app\"; sourceTree = BUILT_PRODUCTS_DIR; };
        \t\tB2000003 /* Melody */ = {isa = PBXFileReference; lastKnownFileType = wrapper; name = Melody; path = \"\(melodyPackagePath)\"; sourceTree = \"<group>\"; };
        \t\tB2000004 /* DevConfig.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DevConfig.swift; sourceTree = \"<group>\"; };
        \t\tB2000005 /* Manifest.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Manifest.xcconfig; sourceTree = \"<group>\"; };
        \t\tB2000006 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist; path = Info.plist; sourceTree = \"<group>\"; };
        \t\tB2000007 /* app.yaml */ = {isa = PBXFileReference; lastKnownFileType = text.yaml; path = app.yaml; sourceTree = \"<group>\"; };
        \t\tB2000008 /* screens */ = {isa = PBXFileReference; lastKnownFileType = folder; path = screens; sourceTree = \"<group>\"; };
        \t\tB2000009 /* components */ = {isa = PBXFileReference; lastKnownFileType = folder; path = components; sourceTree = \"<group>\"; };
        \t\tB2000010 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; };
        \t\tB2000011 /* assets */ = {isa = PBXFileReference; lastKnownFileType = folder; path = assets; sourceTree = \"<group>\"; };
        /* End PBXFileReference section */

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
        /* End PBXFrameworksBuildPhase section */

        /* Begin PBXGroup section */
        \t\tB5000001 = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\tB2000006 /* Info.plist */,
        \t\t\t\tB2000005 /* Manifest.xcconfig */,
        \t\t\t\tB2000001 /* App.swift */,
        \t\t\t\tB2000004 /* DevConfig.swift */,
        \t\t\t\tB2000007 /* app.yaml */,
        \t\t\t\tB2000008 /* screens */,
        \t\t\t\tB2000009 /* components */,
        \t\t\t\tB2000010 /* Assets.xcassets */,
        \t\t\t\tB2000011 /* assets */,
        \t\t\t\tB5000003 /* Packages */,
        \t\t\t\tB5000002 /* Products */,
        \t\t\t);
        \t\t\tsourceTree = \"<group>\";
        \t\t};
        \t\tB5000002 /* Products */ = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\tB2000002 /* \(name).app */,
        \t\t\t);
        \t\t\tname = Products;
        \t\t\tsourceTree = \"<group>\";
        \t\t};
        \t\tB5000003 /* Packages */ = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\tB2000003 /* Melody */,
        \t\t\t);
        \t\t\tname = Packages;
        \t\t\tsourceTree = \"<group>\";
        \t\t};
        /* End PBXGroup section */

        /* Begin PBXNativeTarget section */
        \t\tB6000001 /* \(name) */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = B8000003 /* Build configuration list for PBXNativeTarget \"\(name)\" */;
        \t\t\tbuildPhases = (
        \t\t\t\tB7000001 /* Sources */,
        \t\t\t\tB3000001 /* Frameworks */,
        \t\t\t\tB3000002 /* Resources */,
        \t\t\t\tB3000003 /* Generate macOS Icon */,
        \t\t\t);
        \t\t\tbuildRules = (
        \t\t\t);
        \t\t\tdependencies = (
        \t\t\t);
        \t\t\tname = \(name);
        \t\t\tpackageProductDependencies = (
        \t\t\t\tB4000001 /* Runtime */,
        \t\t\t\tB4000002 /* Core */,
        \t\t\t);
        \t\t\tproductName = \(name);
        \t\t\tproductReference = B2000002 /* \(name).app */;
        \t\t\tproductType = \"com.apple.product-type.application\";
        \t\t};
        /* End PBXNativeTarget section */

        /* Begin PBXProject section */
        \t\tB9000001 /* Project object */ = {
        \t\t\tisa = PBXProject;
        \t\t\tattributes = {
        \t\t\t\tBuildIndependentTargetsInParallel = 1;
        \t\t\t\tLastSwiftUpdateCheck = 1540;
        \t\t\t\tLastUpgradeCheck = 1540;
        \t\t\t\tTargetAttributes = {
        \t\t\t\t\tB6000001 = {
        \t\t\t\t\t\tCreatedOnToolsVersion = 15.4;
        \t\t\t\t\t};
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
        \t\t\tproductRefGroup = B5000002 /* Products */;
        \t\t\tprojectDirPath = \"\";
        \t\t\tprojectRoot = \"\";
        \t\t\ttargets = (
        \t\t\t\tB6000001 /* \(name) */,
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
        /* End PBXResourcesBuildPhase section */

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
        /* End PBXShellScriptBuildPhase section */

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
        /* End PBXSourcesBuildPhase section */

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
        /* End XCBuildConfiguration section */

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
        /* End XCConfigurationList section */

        /* Begin XCSwiftPackageProductDependency section */
        \t\tB4000001 /* Runtime */ = {
        \t\t\tisa = XCSwiftPackageProductDependency;
        \t\t\tproductName = Runtime;
        \t\t};
        \t\tB4000002 /* Core */ = {
        \t\t\tisa = XCSwiftPackageProductDependency;
        \t\t\tproductName = Core;
        \t\t};
        /* End XCSwiftPackageProductDependency section */
        \t};
        \trootObject = B9000001 /* Project object */;
        }
        """
    }
}
