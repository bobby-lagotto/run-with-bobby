import SwiftUI

struct SettingsView: View {
    @ObservedObject var aiSettings: AISettings
    @ObservedObject var healthManager: HealthKitManager
    var onHealthChanged: (() -> Void)?
    var onProviderChanged: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var apiKeyValidated = false
    @State private var validationMessage = ""
    @State private var isValidating = false
    @State private var healthConnected: Bool = UserDefaults.standard.bool(forKey: "healthkit_connected")
    @State private var showingHealthError = false
    @State private var healthErrorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                providerSection
                openAISection
                localModelSection
                healthSection
                infoSection
            }
            .scrollContentBackground(.hidden)
            .background(BobbyTheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Impostazioni AI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") { dismiss() }
                        .foregroundColor(.bobbyWarmGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.bobbyRed)
                }
            }
            .onAppear {
                apiKeyInput = aiSettings.openAIAPIKey ?? ""
            }
        }
    }

    // MARK: - Provider Selection

    private var providerSection: some View {
        Section {
            ForEach(LLMProviderType.allCases, id: \.self) { type in
                HStack(spacing: 12) {
                    Image(systemName: type.icon)
                        .foregroundColor(aiSettings.providerType == type ? .bobbyRed : .bobbyWarmGray)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.rawValue)
                            .font(.body)
                        Text(providerDescription(for: type))
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                    }

                    Spacer()

                    if aiSettings.providerType == type {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.bobbyRed)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    aiSettings.providerType = type
                }
            }
        } header: {
            Label("Provider AI", systemImage: "cpu")
                .foregroundColor(.bobbyRed)
        }
    }

    // MARK: - OpenAI Section

    private var openAISection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                if showingAPIKey {
                    TextField("sk-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("API Key OpenAI", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Button(action: { showingAPIKey.toggle() }) {
                    Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                        .foregroundColor(.bobbyWarmGray)
                }
            }

            if !apiKeyInput.isEmpty {
                Button(action: validateAPIKey) {
                    HStack {
                        if isValidating {
                            ProgressView()
                                .tint(.bobbyRed)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: apiKeyValidated ? "checkmark.circle.fill" : "arrow.clockwise")
                                .foregroundColor(apiKeyValidated ? .green : .bobbyRed)
                        }
                        Text(isValidating ? "Verifica in corso..." : (apiKeyValidated ? "API Key valida" : "Verifica API Key"))
                            .foregroundColor(apiKeyValidated ? .green : .bobbyRed)
                    }
                }
                .disabled(isValidating)
            }

            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(apiKeyValidated ? .green : .red)
            }

            HStack(spacing: 12) {
                Image(systemName: "brain")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                Picker("Modello", selection: $aiSettings.openAIModel) {
                    Text("GPT-4o Mini").tag("gpt-4o-mini")
                    Text("GPT-4o").tag("gpt-4o")
                    Text("GPT-4.1 Mini").tag("gpt-4.1-mini")
                    Text("GPT-4.1").tag("gpt-4.1")
                }
            }
        } header: {
            Label("OpenAI", systemImage: "cloud")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("La API key viene salvata in modo sicuro nel Keychain del dispositivo.")
                .font(.caption)
        }
    }

    // MARK: - Local Model Section

    private var localModelSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(aiSettings.localModelName)
                        .font(.body)

                    if aiSettings.isModelDownloaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Scaricato")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else if aiSettings.isDownloading {
                        ProgressView(value: aiSettings.downloadProgress)
                            .tint(.bobbyRed)
                        Text("Download: \(Int(aiSettings.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                    } else {
                        Text("Non scaricato (~2 GB)")
                            .font(.caption)
                            .foregroundColor(.bobbyWarmGray)
                    }
                }

                Spacer()

                if !aiSettings.isModelDownloaded && !aiSettings.isDownloading {
                    Button("Scarica") {
                        // MLX model download will be implemented with MLXProvider
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.bobbyRed)
                    .clipShape(Capsule())
                }
            }
        } header: {
            Label("Modello Locale", systemImage: "iphone")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Il modello locale funziona completamente offline sul dispositivo. Richiede iPhone 12 o successivo.")
                .font(.caption)
        }
    }

    // MARK: - Health Section

    private var healthSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                        .font(.body)
                    Text(healthStatusDescription)
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                }

                Spacer()

                Toggle("", isOn: $healthConnected)
                    .tint(.bobbyRed)
                    .onChange(of: healthConnected) { _, newValue in
                        handleHealthToggle(newValue)
                    }
            }

            if healthConnected && healthManager.isAuthorized {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .frame(width: 28)
                    Text("Bobby può analizzare i tuoi dati di salute in chat")
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                }
            }

            if !healthConnected {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.bobbyCaramel)
                        .frame(width: 28)
                    Text("Bobby leggerà frequenza cardiaca, HRV, passi, sonno, allenamenti e VO2 Max per analizzare il tuo stato fisico.")
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                }
            }
        } header: {
            Label("Salute", systemImage: "heart.text.clipboard")
                .foregroundColor(.bobbyRed)
        } footer: {
            if healthConnected {
                Text("I dati vengono letti in sola lettura. Per revocare l'accesso vai in Impostazioni > Salute > Accesso Dati.")
                    .font(.caption)
            }
        }
        .alert("Errore", isPresented: $showingHealthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(healthErrorMessage)
        }
    }

    private var healthStatusDescription: String {
        if !healthManager.isAvailable {
            return "Non disponibile su questo dispositivo"
        }
        if healthConnected {
            return healthManager.isAuthorized ? "Collegato" : "In attesa di autorizzazione"
        }
        return "Non collegato"
    }

    private func handleHealthToggle(_ connect: Bool) {
        if connect {
            guard healthManager.isAvailable else {
                healthConnected = false
                healthErrorMessage = "HealthKit non è disponibile su questo dispositivo."
                showingHealthError = true
                return
            }
            Task {
                let authorized = await healthManager.requestAuthorization()
                await MainActor.run {
                    if !authorized {
                        healthConnected = false
                        healthErrorMessage = "Autorizzazione Health non concessa. Puoi attivarla in Impostazioni > Salute."
                        showingHealthError = true
                    }
                    UserDefaults.standard.set(healthConnected, forKey: "healthkit_connected")
                    onHealthChanged?()
                }
            }
        } else {
            UserDefaults.standard.set(false, forKey: "healthkit_connected")
            onHealthChanged?()
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider attivo")
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)

                    Text(currentProviderDescription)
                        .font(.body)
                }
            }
        } header: {
            Label("Stato", systemImage: "gauge.with.dots.needle.33percent")
                .foregroundColor(.bobbyRed)
        }
    }

    // MARK: - Helpers

    private var currentProviderDescription: String {
        switch aiSettings.providerType {
        case .local:
            return aiSettings.isModelDownloaded ? "Modello locale attivo" : "Modello locale non disponibile"
        case .openai:
            return aiSettings.hasAPIKey ? "OpenAI \(aiSettings.openAIModel)" : "API Key mancante"
        case .auto:
            if aiSettings.isModelDownloaded {
                return "Locale (con fallback OpenAI)"
            } else if aiSettings.hasAPIKey {
                return "OpenAI \(aiSettings.openAIModel)"
            } else {
                return "Nessun provider configurato"
            }
        }
    }

    private func providerDescription(for type: LLMProviderType) -> String {
        switch type {
        case .local: return "Modello on-device, privacy totale"
        case .openai: return "Cloud, più preciso e veloce"
        case .auto: return "Locale se disponibile, altrimenti cloud"
        }
    }

    private func saveSettings() {
        if !apiKeyInput.isEmpty {
            aiSettings.openAIAPIKey = apiKeyInput
        } else {
            aiSettings.openAIAPIKey = nil
        }
        onProviderChanged?()
    }

    private func validateAPIKey() {
        isValidating = true
        validationMessage = ""

        Task {
            do {
                let provider = OpenAIProvider(apiKey: apiKeyInput, model: "gpt-4o-mini")
                let testMessages = [
                    LLMMessage(role: .system, content: "Rispondi solo 'OK'"),
                    LLMMessage(role: .user, content: "Test")
                ]
                let response = try await provider.generate(messages: testMessages, toolDefinitions: nil)

                await MainActor.run {
                    isValidating = false
                    if !response.text.isEmpty {
                        apiKeyValidated = true
                        validationMessage = "Connessione riuscita!"
                    } else {
                        apiKeyValidated = false
                        validationMessage = "Risposta vuota dal server."
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    apiKeyValidated = false
                    validationMessage = "Errore: \(error.localizedDescription)"
                }
            }
        }
    }
}
