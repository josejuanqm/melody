#if MELODY_DEV
import SwiftUI

/// Settings panel for configuring the dev server host, port, and viewing logs.
struct DevSettingsView: View {
    @Bindable var settings: DevSettings
    var logger: DevLogger
    var hotReload: HotReloadClient
    var onReconnect: () -> Void

    @State private var portText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Hot Reload") {
                    Toggle("Enabled", isOn: $settings.hotReloadEnabled)

                    HStack {
                        Text("Status")
                        Spacer()
                        Circle()
                            .fill(hotReload.isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(hotReload.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }

                    TextField("Host", text: $settings.devServerHost)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("Port", text: $portText)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .frame(width: 80)
                            .onChange(of: portText) { _, newValue in
                                if let port = Int(newValue) {
                                    settings.devServerPort = port
                                }
                            }
                    }

                    Button("Reconnect") {
                        onReconnect()
                    }
                }

                Section {
                    NavigationLink {
                        DevLogView(logger: logger)
                    } label: {
                        HStack {
                            Text("Logs")
                            Spacer()
                            Text("\(logger.entries.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Dev Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                portText = String(settings.devServerPort)
            }
        }
    }
}

// MARK: - Dedicated Log Viewer

/// Scrollable log viewer for hot-reload and Lua log entries.
struct DevLogView: View {
    var logger: DevLogger

    var body: some View {
        Group {
            if logger.entries.isEmpty {
                ContentUnavailableView("No Logs", systemImage: "text.alignleft")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logger.entries.reversed()) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text("[\(entry.source)]")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(colorForSource(entry.source))
                                Text(entry.message)
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Logs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Clear") {
                    logger.clear()
                }
                .disabled(logger.entries.isEmpty)
            }
        }
    }

    private func colorForSource(_ source: String) -> Color {
        switch source {
        case "lua": return .blue
        case "hotreload": return .orange
        default: return .secondary
        }
    }
}
#endif
