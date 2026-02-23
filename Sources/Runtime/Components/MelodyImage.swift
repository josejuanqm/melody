import SwiftUI
import Core
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Renders an image from a URL, bundled asset, or SF Symbol.
struct MelodyImage: View {
    let definition: ComponentDefinition
    var resolvedSrc: String? = nil
    var resolvedSystemImage: String? = nil
    @Environment(\.themeColors) private var themeColors
    @Environment(\.isInFormContext) private var isInFormContext
    @Environment(\.assetBaseURL) private var assetBaseURL

    private var imageColor: Color {
        StyleResolver.color(from: definition.style, default: .primary, themeColors: themeColors)
    }

    private var contentMode: ContentMode {
        ContentModeVariant(definition.style?.contentMode) == .fill ? .fill : .fit
    }

    var body: some View {
        Group {
            if let systemImage = resolvedSystemImage ?? definition.systemImage?.literalValue, !systemImage.isEmpty {
                Image(systemName: systemImage)
                    .resizable()
                    .aspectRatio(contentMode: isInFormContext ? .fit : contentMode)
                    .foregroundStyle(imageColor)
            } else if let src = resolvedSrc ?? definition.src?.literalValue, !src.isEmpty, src.hasPrefix("assets/") {
                if let baseURL = assetBaseURL, let url = URL(string: "\(baseURL)/\(src)") {
                    asyncImageView(url: url)
                } else {
                    bundledAssetImage(path: src)
                }
            } else if let src = resolvedSrc ?? definition.src?.literalValue,
                      !src.isEmpty,
                      let url = URL(string: src) {
                asyncImageView(url: url)
            } else {
                EmptyView()
            }
        }
        .melodyStyle(definition.style)
        .clipped()
    }

    @ViewBuilder
    private func asyncImageView(url: URL) -> some View {
        ZStack(alignment: .center) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: isInFormContext ? .fit : contentMode)
                case .failure:
                    Color.black.opacity(0.1)
                        .overlay {
                            ZStack(alignment: .center) {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                        }
                case .empty:
                    Color.black.opacity(0.1)
                        .overlay {
                            ZStack(alignment: .center) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                            }
                        }
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private func bundledAssetImage(path: String) -> some View {
        let nsPath = path as NSString
        let directory = nsPath.deletingLastPathComponent
        let filename = (nsPath.lastPathComponent as NSString).deletingPathExtension
        let ext = nsPath.pathExtension

        let url = Bundle.main.url(forResource: filename, withExtension: ext, subdirectory: directory)
            ?? Bundle.main.url(forResource: filename, withExtension: ext)
        if let url,
           let data = try? Data(contentsOf: url),
           let image = platformImage(from: data) {
            image.resizable()
                .aspectRatio(contentMode: isInFormContext ? .fit : contentMode)
        } else {
            Color.black.opacity(0.1)
                .overlay {
                    ZStack(alignment: .center) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
        }
    }

    private func platformImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
