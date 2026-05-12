import SwiftUI

struct SettingsView: View {
    @ObservedObject var aiSettings: AISettings
    @ObservedObject var healthManager: HealthKitManager
    @ObservedObject var mlxProvider: MLXProvider
    var onHealthChanged: (() -> Void)?
    var onProviderChanged: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    // OpenAI state
    @State private var apiKeyInput: String = ""
    @State private var showingAPIKey = false
    @State private var apiKeyValidated = false
    @State private var validationMessage = ""
    @State private var isValidating = false

    // Anthropic state
    @State private var anthropicKeyInput: String = ""
    @State private var showingAnthropicKey = false
    @State private var anthropicKeyValidated = false
    @State private var anthropicValidationMessage = ""
    @State private var isValidatingAnthropic = false

    // Clipboard detection
    @State private var clipboardKey: String?
    @State private var clipboardKeyType: ClipboardKeyType?

    // Other state
    @State private var healthConnected: Bool = UserDefaults.standard.bool(forKey: "healthkit_connected")
    @State private var showingHealthError = false
    @State private var healthErrorMessage = ""
    @State private var downloadError: String?
    @State private var showingAPIKeyGuide = false

    enum ClipboardKeyType {
        case openai, anthropic
    }

    var body: some View {
        NavigationView {
            Form {
                providerSection
                openAISection
                anthropicSection
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
                anthropicKeyInput = aiSettings.anthropicAPIKey ?? ""
                detectClipboardKey()
            }
            .sheet(isPresented: $showingAPIKeyGuide) {
                APIKeyGuideView()
            }
        }
    }

    // MARK: - Clipboard Detection

    private func detectClipboardKey() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else { return }
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)

        if AISettings.looksLikeAnthropicKey(trimmed) && anthropicKeyInput.isEmpty {
            clipboardKey = trimmed
            clipboardKeyType = .anthropic
        } else if AISettings.looksLikeOpenAIKey(trimmed) && apiKeyInput.isEmpty {
            clipboardKey = trimmed
            clipboardKeyType = .openai
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
            // Clipboard banner
            if let key = clipboardKey, clipboardKeyType == .openai {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.bobbyRed)
                    Text("API Key trovata negli appunti")
                        .font(.caption)
                    Spacer()
                    Button("Usa") {
                        apiKeyInput = key
                        clipboardKey = nil
                        clipboardKeyType = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.bobbyRed)
                }
                .padding(.vertical, 4)
            }

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
                Button(action: validateOpenAIKey) {
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

            // Deep link + guide
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://platform.openai.com/api-keys") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Ottieni API Key")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.bobbyRed)
                }

                Spacer()

                Button {
                    showingAPIKeyGuide = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("Guida")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.bobbyWarmGray)
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

    // MARK: - Anthropic Section

    private var anthropicSection: some View {
        Section {
            // Clipboard banner
            if let key = clipboardKey, clipboardKeyType == .anthropic {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.bobbyRed)
                    Text("API Key Anthropic trovata negli appunti")
                        .font(.caption)
                    Spacer()
                    Button("Usa") {
                        anthropicKeyInput = key
                        clipboardKey = nil
                        clipboardKeyType = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.bobbyRed)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                if showingAnthropicKey {
                    TextField("sk-ant-...", text: $anthropicKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("API Key Anthropic", text: $anthropicKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Button(action: { showingAnthropicKey.toggle() }) {
                    Image(systemName: showingAnthropicKey ? "eye.slash" : "eye")
                        .foregroundColor(.bobbyWarmGray)
                }
            }

            if !anthropicKeyInput.isEmpty {
                Button(action: validateAnthropicKey) {
                    HStack {
                        if isValidatingAnthropic {
                            ProgressView()
                                .tint(.bobbyRed)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: anthropicKeyValidated ? "checkmark.circle.fill" : "arrow.clockwise")
                                .foregroundColor(anthropicKeyValidated ? .green : .bobbyRed)
                        }
                        Text(isValidatingAnthropic ? "Verifica in corso..." : (anthropicKeyValidated ? "API Key valida" : "Verifica API Key"))
                            .foregroundColor(anthropicKeyValidated ? .green : .bobbyRed)
                    }
                }
                .disabled(isValidatingAnthropic)
            }

            if !anthropicValidationMessage.isEmpty {
                Text(anthropicValidationMessage)
                    .font(.caption)
                    .foregroundColor(anthropicKeyValidated ? .green : .red)
            }

            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                Picker("Modello", selection: $aiSettings.anthropicModel) {
                    Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                    Text("Claude Haiku 3.5").tag("claude-haiku-4-5-20251001")
                }
            }

            // Deep link
            Button {
                if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Ottieni API Key")
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.bobbyRed)
            }
        } header: {
            Label("Anthropic", systemImage: "brain.head.profile")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Claude eccelle nel seguire istruzioni complesse e nel tool-calling in italiano.")
                .font(.caption)
        }
    }

    // MARK: - Local Model Section

    private var localModelSection: some View {
        Section {
            ForEach(LocalModelCatalog.all) { option in
                localModelRow(for: option)
            }

            if let downloadError {
                Text("Errore: \(downloadError)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Label("Modello Locale", systemImage: "iphone")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Tocca un modello per selezionarlo. I modelli funzionano completamente offline. Puoi tenerne più di uno scaricato e cambiare quando vuoi.")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func localModelRow(for option: LocalModelOption) -> some View {
        let isSelected = aiSettings.selectedModelId == option.id
        let isDownloaded = aiSettings.downloadedModelIds.contains(option.id)
        let isSupported = option.isSupportedOnThisDevice
        let isThisDownloading = mlxProvider.isDownloading && mlxProvider.modelId == option.id
        let isRecommended = option.id == LocalModelCatalog.defaultId

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .bobbyRed : .bobbyWarmGray)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.tier)
                            .font(.body.weight(.semibold))
                            .foregroundColor(isSupported ? .primary : .secondary)
                        Text("·")
                            .foregroundColor(.bobbyWarmGray)
                        Text(option.formattedSize)
                            .font(.subheadline)
                            .foregroundColor(.bobbyWarmGray)
                        if isRecommended {
                            Text("⭐ Consigliato")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.bobbyCaramel)
                        }
                    }
                    Text(option.shortName)
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                }

                Spacer()
            }

            Text(option.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !isSupported {
                Text(option.requirementText)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.orange)
            } else if isThisDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: mlxProvider.downloadProgress)
                        .tint(.bobbyRed)
                    Text("Download: \(Int(mlxProvider.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                }
            } else {
                HStack(spacing: 8) {
                    if isDownloaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(isSelected ? "Scaricato · Attivo" : "Scaricato")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.green)
                        }
                        Spacer()
                        if !isSelected {
                            Button("Elimina") {
                                mlxProvider.deleteModelFiles(option.id)
                                aiSettings.markDeleted(option.id)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.bobbyRed)
                        }
                    } else {
                        Spacer()
                        Button("Scarica") {
                            downloadModel(option)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.bobbyRed)
                        .clipShape(Capsule())
                        .disabled(mlxProvider.isDownloading)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .opacity(isSupported ? 1.0 : 0.55)
        .onTapGesture {
            guard isSupported, isDownloaded, !mlxProvider.isDownloading else { return }
            aiSettings.selectedModelId = option.id
            onProviderChanged?()
        }
    }

    private func downloadModel(_ option: LocalModelOption) {
        downloadError = nil
        mlxProvider.setModel(option.id)
        Task {
            aiSettings.isDownloading = true
            do {
                try await mlxProvider.downloadModel()
                aiSettings.markDownloaded(option.id)
                aiSettings.selectedModelId = option.id
                aiSettings.isDownloading = false
                onProviderChanged?()
            } catch {
                aiSettings.isDownloading = false
                downloadError = error.localizedDescription
            }
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
            return aiSettings.isLocalAvailable ? "Modello locale attivo" : "Modello locale non disponibile"
        case .openai:
            return aiSettings.hasOpenAIKey ? "OpenAI \(aiSettings.openAIModel)" : "API Key mancante"
        case .anthropic:
            return aiSettings.hasAnthropicKey ? "Anthropic \(aiSettings.anthropicModel)" : "API Key mancante"
        case .auto:
            if aiSettings.isLocalAvailable {
                return "Locale (con fallback cloud)"
            } else if aiSettings.hasAnthropicKey {
                return "Anthropic \(aiSettings.anthropicModel)"
            } else if aiSettings.hasOpenAIKey {
                return "OpenAI \(aiSettings.openAIModel)"
            } else {
                return "Nessun provider configurato"
            }
        }
    }

    private func providerDescription(for type: LLMProviderType) -> String {
        switch type {
        case .local: return "Modello on-device, privacy totale"
        case .openai: return "Cloud OpenAI, veloce e preciso"
        case .anthropic: return "Cloud Anthropic, ottimo in italiano"
        case .auto: return "Locale se disponibile, altrimenti cloud"
        }
    }

    private func saveSettings() {
        if !apiKeyInput.isEmpty {
            aiSettings.openAIAPIKey = apiKeyInput
        } else {
            aiSettings.openAIAPIKey = nil
        }
        if !anthropicKeyInput.isEmpty {
            aiSettings.anthropicAPIKey = anthropicKeyInput
        } else {
            aiSettings.anthropicAPIKey = nil
        }
        onProviderChanged?()
    }

    // MARK: - Validation

    private func validateOpenAIKey() {
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
                    validationMessage = parseAPIError(error)
                }
            }
        }
    }

    private func validateAnthropicKey() {
        isValidatingAnthropic = true
        anthropicValidationMessage = ""

        Task {
            do {
                let provider = AnthropicProvider(apiKey: anthropicKeyInput, model: "claude-haiku-4-5-20251001")
                let testMessages = [
                    LLMMessage(role: .user, content: "Rispondi solo 'OK'")
                ]
                let response = try await provider.generate(messages: testMessages, toolDefinitions: nil)

                await MainActor.run {
                    isValidatingAnthropic = false
                    if !response.text.isEmpty {
                        anthropicKeyValidated = true
                        anthropicValidationMessage = "Connessione riuscita!"
                    } else {
                        anthropicKeyValidated = false
                        anthropicValidationMessage = "Risposta vuota dal server."
                    }
                }
            } catch {
                await MainActor.run {
                    isValidatingAnthropic = false
                    anthropicKeyValidated = false
                    anthropicValidationMessage = parseAPIError(error)
                }
            }
        }
    }

    private func parseAPIError(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("401") {
            return "Chiave API non valida. Verifica di averla copiata correttamente."
        } else if message.contains("429") {
            return "Troppi tentativi. Riprova tra qualche secondo."
        } else if message.contains("402") || message.contains("insufficient_quota") || message.contains("billing") {
            return "Credito esaurito. Ricarica il tuo account sul portale del provider."
        } else if message.contains("403") {
            return "Accesso negato. Verifica i permessi della tua API key."
        } else if message.contains("timeout") || message.contains("Timeout") {
            return "Timeout di connessione. Verifica la tua connessione internet."
        }
        return "Errore: \(message)"
    }
}

// MARK: - API Key Guide View

struct APIKeyGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Come ottenere una API Key")
                        .font(.title2.weight(.bold))
                        .padding(.top)

                    guideStep(
                        number: 1,
                        icon: "person.crop.circle",
                        title: "Crea un account",
                        description: "Registrati su platform.openai.com (OpenAI) o console.anthropic.com (Anthropic) se non hai ancora un account."
                    )

                    guideStep(
                        number: 2,
                        icon: "creditcard",
                        title: "Aggiungi un metodo di pagamento",
                        description: "Vai nella sezione Billing del portale e aggiungi una carta. I costi sono a consumo (pochi centesimi per conversazione)."
                    )

                    guideStep(
                        number: 3,
                        icon: "key.fill",
                        title: "Genera la API Key",
                        description: "Nella sezione API Keys, clicca 'Create new secret key'. Copiala subito: non potrai rivederla."
                    )

                    guideStep(
                        number: 4,
                        icon: "doc.on.clipboard",
                        title: "Incolla nell'app",
                        description: "Torna in Run with Bobby e incolla la chiave nel campo corrispondente. Verrà salvata in modo sicuro nel Keychain del dispositivo."
                    )

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Link rapidi")
                            .font(.headline)

                        Button {
                            if let url = URL(string: "https://platform.openai.com/api-keys") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("OpenAI API Keys")
                                Spacer()
                            }
                            .foregroundColor(.bobbyRed)
                        }

                        Button {
                            if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Anthropic API Keys")
                                Spacer()
                            }
                            .foregroundColor(.bobbyRed)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.bobbyRed)
                }
            }
        }
    }

    private func guideStep(number: Int, icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.bobbyRed.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(.bobbyRed)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(title)")
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
