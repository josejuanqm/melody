#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
import Core

/// Reusable SwiftUI view for rendering a Melody widget entry.
public struct MelodyWidgetView: View {

    let entry: MelodyWidgetEntry

    public init(entry: MelodyWidgetEntry) {
        self.entry = entry
    }

    public var body: some View {
        let layout = selectLayout()
        let resolvedComponents = layout.map {
            WidgetExpressionResolver.resolve(components: $0.body, data: entry.data)
        }

        Group {
            if let components = resolvedComponents, !components.isEmpty {
                VStack(spacing: 0) {
                    WidgetComponentRenderer(components: components, themeColors: entry.themeColors)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entry.widgetDefinition.configure != nil {
                configurePrompt
            } else {
                Text(entry.widgetDefinition.name ?? entry.widgetDefinition.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            if let bgResolved = WidgetExpressionResolver.resolveValue(layout?.background, data: entry.data),
               !bgResolved.isEmpty {
                resolveColor(bgResolved, themeColors: entry.themeColors)
            } else {
                Color.clear
            }
        }
        .widgetURL(deepLinkURL)
    }

    private var configurePrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "gear")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Tap and hold to configure")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var deepLinkURL: URL? {
        if let link = entry.widgetDefinition.link {
            return URL(string: link)
        }
        return nil
    }

    private func selectLayout() -> WidgetLayout? {
        guard let layouts = entry.widgetDefinition.layouts else { return nil }
        if let layout = layouts[entry.family] { return layout }
        return layouts.values.first
    }
}
#endif
