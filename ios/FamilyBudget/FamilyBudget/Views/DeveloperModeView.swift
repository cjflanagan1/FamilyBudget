import SwiftUI

struct DeveloperModeView: View {
    @ObservedObject private var debugManager = DebugManager.shared
    @State private var customAPIURL = ""
    @State private var showExportSheet = false
    @State private var exportedLogs = ""

    var body: some View {
        List {
            // Debug toggles
            Section("Debug Options") {
                Toggle("Anonymize Names", isOn: $debugManager.anonymizeNames)

                Toggle("Show Raw API Responses", isOn: $debugManager.showRawResponses)
            }

            // Plaid environment
            Section("Plaid Environment") {
                Picker("Environment", selection: $debugManager.plaidEnvironment) {
                    ForEach(DebugManager.PlaidEnvironment.allCases, id: \.self) { env in
                        Text(env.rawValue.capitalized).tag(env)
                    }
                }
                .pickerStyle(.inline)

                Text("Current: \(debugManager.plaidEnvironment.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // API Configuration
            Section("API Configuration") {
                TextField("Custom API URL", text: $customAPIURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Save API URL") {
                    debugManager.setAPIURL(customAPIURL)
                }

                Text("Current: \(debugManager.apiBaseURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Test actions
            Section("Test Actions") {
                Button {
                    debugManager.triggerTestNotification()
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Send Test Notification")
                    }
                }

                Button {
                    debugManager.clearCache()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Local Cache")
                    }
                }
                .foregroundColor(.red)
            }

            // API Logs
            Section("API Logs (\(debugManager.apiLogs.count))") {
                if debugManager.apiLogs.isEmpty {
                    Text("No API calls logged yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(debugManager.apiLogs.prefix(20)) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(log.method)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(methodColor(log.method))
                                    .cornerRadius(4)

                                Text(log.formattedTimestamp)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(log.statusCode)")
                                    .font(.caption)
                                    .foregroundColor(log.isSuccess ? .green : .red)
                            }

                            Text(log.endpoint)
                                .font(.caption)
                                .lineLimit(1)

                            if debugManager.showRawResponses, let response = log.response {
                                Text(response.prefix(200))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button("Clear Logs") {
                        debugManager.clearLogs()
                    }
                    .foregroundColor(.red)

                    Button("Export Logs") {
                        exportedLogs = debugManager.exportLogs()
                        showExportSheet = true
                    }
                }
            }

            // Disable developer mode
            Section {
                Button {
                    debugManager.isDebugMode = false
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Disable Developer Mode")
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle("Developer Mode")
        .onAppear {
            customAPIURL = debugManager.apiBaseURL
        }
        .sheet(isPresented: $showExportSheet) {
            NavigationView {
                ScrollView {
                    Text(exportedLogs)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .textSelection(.enabled)
                }
                .navigationTitle("Exported Logs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showExportSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        ShareLink(item: exportedLogs) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .blue
        case "POST": return .green
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }
}

#Preview {
    NavigationView {
        DeveloperModeView()
    }
}
