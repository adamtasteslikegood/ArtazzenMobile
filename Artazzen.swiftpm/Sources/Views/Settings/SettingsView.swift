import ArtazzenCore
import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @AppStorage(SettingsStorage.darkMode) private var darkMode = false

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            Form {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $darkMode)
                }

                Section("Artazzen Server") {
                    TextField("Server URL", text: $session.serverURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: session.serverURLString) { _, _ in session.loadDraftPassword()
                        }
                    TextField("Admin username", text: $session.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: session.username) { _, _ in session.loadDraftPassword() }
                    SecureField("Admin password", text: $session.password)
                    Button("Connect and Load") {
                        Task { await session.connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.azTeal)
                    if let error = session.lastError {
                        Text(error)
                            .font(.azMono)
                            .foregroundStyle(.red)
                    } else if let message = session.lastMessage {
                        Text(message)
                            .font(.azMono)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("AI Metadata") {
                    Toggle("Enable AI Generation", isOn: $session.aiConfig.enabled)

                    Picker("Model", selection: $session.aiConfig.model) {
                        Text("gpt-4o-mini").tag("gpt-4o-mini")
                        Text("gpt-5-mini").tag("gpt-5-mini")
                    }

                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.1f", session.aiConfig.temperature))
                            .font(.azMono)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $session.aiConfig.temperature, in: 0...2, step: 0.1)

                    Stepper(
                        "Max Tokens: \(session.aiConfig.maxOutputTokens)",
                        value: $session.aiConfig.maxOutputTokens,
                        in: 16...4000,
                        step: 50
                    )
                }
                .disabled(!session.hasLoadedConfig || session.isSavingConfig)

                if let error = session.configError {
                    Section {
                        Text(error).foregroundStyle(.orange)
                        Button("Retry AI Settings") { Task { await session.retryConfig() } }
                    }
                }
                if let error = session.collectionsError {
                    Section {
                        Text(error).foregroundStyle(.orange)
                        Button("Retry Collections") { Task { await session.retryCollections() } }
                    }
                }

                Section {
                    Button("Save Settings") {
                        Task { await session.saveAIConfig() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.azTeal)

                    Button("Reset to Defaults", role: .destructive) {
                        session.aiConfig = AIConfig(
                            enabled: true,
                            model: "gpt-4o-mini",
                            temperature: 0.6,
                            maxOutputTokens: 600
                        )
                    }
                }
                .disabled(!session.hasLoadedConfig || session.isSavingConfig)

                Section("About") {
                    LabeledContent(
                        "Connected Server", value: session.activeServer ?? "Not connected")
                    LabeledContent("Version", value: "1.0.0")
                    Text(
                        "Admin JSON: GET /admin/api/new-files. Docs: artazzen.com/docs"
                    )
                    .font(.azMono)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
