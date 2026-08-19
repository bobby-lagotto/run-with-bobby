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

    // OpenRouter state
    @State private var openRouterKeyInput: String = ""
    @State private var showingOpenRouterKey = false
    @State private var openRouterKeyValidated = false
    @State private var openRouterValidationMessage = ""
    @State private var isValidatingOpenRouter = false

    // Clipboard detection
    @State private var clipboardKey: String?
    @State private var clipboardKeyType: ClipboardKeyType?
    @State private var clipboardChecked = false

    // Other state
    @State private var healthConnected: Bool = UserDefaults.standard.bool(forKey: "healthkit_connected")
    @State private var showingHealthError = false
    @State private var healthErrorMessage = ""
    @State private var downloadError: String?

    enum ClipboardKeyType {
        case openai, anthropic, openrouter
    }

    var body: some View {
        NavigationView {
            Form {
                providerSection
                openAISection
                anthropicSection
                openRouterSection
                qwenModelSection
                bonsaiModelSection
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
                openRouterKeyInput = aiSettings.openRouterAPIKey ?? ""
            }
        }
    }

    // MARK: - Clipboard Detection

    private func detectClipboardKey() {
        clipboardChecked = true
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else { return }
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)

        if AISettings.looksLikeAnthropicKey(trimmed) && anthropicKeyInput.isEmpty {
            clipboardKey = trimmed
            clipboardKeyType = .anthropic
        } else if AISettings.looksLikeOpenRouterKey(trimmed) && openRouterKeyInput.isEmpty {
            clipboardKey = trimmed
            clipboardKeyType = .openrouter
        } else if AISettings.looksLikeOpenAIKey(trimmed) && apiKeyInput.isEmpty {
            clipboardKey = trimmed
            clipboardKeyType = .openai
        }
    }

    // MARK: - Provider Selection

    private var providerSection: some View {
        Section {
            Button(action: detectClipboardKey) {
                Label("Controlla appunti per API key", systemImage: "doc.on.clipboard")
                    .foregroundColor(.bobbyRed)
            }

            if clipboardChecked && clipboardKey == nil {
                Text("Nessuna API key riconosciuta negli appunti.")
                    .font(.caption)
                    .foregroundColor(.bobbyWarmGray)
            }

            ForEach(LLMProviderType.allCases, id: \.self) { type in
                Button {
                    aiSettings.providerType = type
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .foregroundColor(aiSettings.providerType == type ? .bobbyRed : .bobbyWarmGray)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)
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
                }
                .buttonStyle(.plain)
            }
        } header: {
            Label("Provider AI", systemImage: "cpu")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Gli appunti vengono letti solo quando tocchi il pulsante. Le API key salvate restano nel Keychain.")
                .font(.caption)
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

            cloudDisclosureRow(provider: "OpenAI")
        } header: {
            Label("OpenAI", systemImage: "cloud")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Facoltativo: incolla una API key OpenAI esistente. La chiave resta nel Keychain. Il login ChatGPT consumer non viene usato.")
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

            cloudDisclosureRow(provider: "Anthropic")
        } header: {
            Label("Anthropic", systemImage: "brain.head.profile")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Facoltativo: incolla una API key Anthropic esistente. Il login Claude.ai consumer non viene usato.")
                .font(.caption)
        }
    }

    // MARK: - OpenRouter Section

    private var openRouterSection: some View {
        Section {
            if let key = clipboardKey, clipboardKeyType == .openrouter {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.bobbyRed)
                    Text("API Key OpenRouter trovata negli appunti")
                        .font(.caption)
                    Spacer()
                    Button("Usa") {
                        openRouterKeyInput = key
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

                if showingOpenRouterKey {
                    TextField("sk-or-...", text: $openRouterKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField("API Key OpenRouter", text: $openRouterKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Button(action: { showingOpenRouterKey.toggle() }) {
                    Image(systemName: showingOpenRouterKey ? "eye.slash" : "eye")
                        .foregroundColor(.bobbyWarmGray)
                }
            }

            if !openRouterKeyInput.isEmpty {
                Button(action: validateOpenRouterKey) {
                    HStack {
                        if isValidatingOpenRouter {
                            ProgressView()
                                .tint(.bobbyRed)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: openRouterKeyValidated ? "checkmark.circle.fill" : "arrow.clockwise")
                                .foregroundColor(openRouterKeyValidated ? .green : .bobbyRed)
                        }
                        Text(isValidatingOpenRouter ? "Verifica in corso..." : (openRouterKeyValidated ? "API Key valida" : "Verifica API Key"))
                            .foregroundColor(openRouterKeyValidated ? .green : .bobbyRed)
                    }
                }
                .disabled(isValidatingOpenRouter)
            }

            if !openRouterValidationMessage.isEmpty {
                Text(openRouterValidationMessage)
                    .font(.caption)
                    .foregroundColor(openRouterKeyValidated ? .green : .red)
            }

            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.bobbyCaramel)
                    .frame(width: 28)

                TextField("openai/gpt-4o-mini", text: $aiSettings.openRouterModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            cloudDisclosureRow(provider: "OpenRouter")
        } header: {
            Label("OpenRouter", systemImage: "globe")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Facoltativo: incolla una API key OpenRouter esistente. Il login Claude.ai o ChatGPT consumer non viene usato.")
                .font(.caption)
        }
    }

    // MARK: - Local Model Sections

    private var qwenModelSection: some View {
        Section {
            ForEach(LocalModelCatalog.qwenModels) { option in
                localModelRow(for: option)
            }

            if let downloadError, isDownloadError(for: LocalModelCatalog.qwenModels) {
                Text("Errore: \(downloadError)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Label("Modello locale (Qwen)", systemImage: "iphone")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Tocca un modello per selezionarlo o avviare il download. I Qwen 4-bit sono il default: tool-calling più affidabile per i piani. Puoi tenerne più di uno scaricato.")
                .font(.caption)
        }
    }

    private var bonsaiModelSection: some View {
        Section {
            ForEach(LocalModelCatalog.bonsaiModels) { option in
                localModelRow(for: option)
            }

            if let downloadError, isDownloadError(for: LocalModelCatalog.bonsaiModels) {
                Text("Errore: \(downloadError)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Label("Bonsai (1-bit / ternario)", systemImage: "leaf")
                .foregroundColor(.bobbyRed)
        } footer: {
            Text("Modelli PrismML in MLX, non GGUF. Il ternario 4B è il più adatto alla maggior parte degli iPhone. Il 27B 1-bit è solo per iPhone 17 Pro / Pro Max e non è il default: il tool-calling è meno affidabile.")
                .font(.caption)
        }
    }

    private func isDownloadError(for options: [LocalModelOption]) -> Bool {
        options.contains { $0.id == mlxProvider.modelId }
    }

    @ViewBuilder
    private func localModelRow(for option: LocalModelOption) -> some View {
        let isSelected = aiSettings.selectedModelId == option.id
        let isDownloaded = aiSettings.downloadedModelIds.contains(option.id)
        let isSupported = option.isSupportedOnThisDevice
        let isThisDownloading = mlxProvider.isDownloading && mlxProvider.modelId == option.id
        let isRecommended = option.id == LocalModelCatalog.defaultId

        VStack(alignment: .leading, spacing: 8) {
            Button {
                handleLocalModelTap(for: option)
            } label: {
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
                                Text(option.family.badge)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.bobbyWarmGray)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.bobbyWarmGray.opacity(0.15))
                                    .clipShape(Capsule())
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
                    } else if isDownloaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(isSelected ? "Scaricato · Attivo" : "Scaricato")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isSupported || mlxProvider.isDownloading)
            .opacity(isSupported ? 1.0 : 0.55)

            if isSupported && !isThisDownloading {
                HStack(spacing: 8) {
                    Spacer()
                    if isDownloaded {
                        if !isSelected {
                            Button("Elimina") {
                                mlxProvider.deleteModelFiles(option.id)
                                aiSettings.markDeleted(option.id)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.bobbyRed)
                        }
                    } else {
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
    }

    private func handleLocalModelTap(for option: LocalModelOption) {
        guard option.isSupportedOnThisDevice, !mlxProvider.isDownloading else { return }

        if aiSettings.downloadedModelIds.contains(option.id) {
            aiSettings.selectedModelId = option.id
            onProviderChanged?()
        } else {
            downloadModel(option)
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
                    Text("Bobby può leggere in sola lettura i tuoi dati di salute in chat")
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                }
            }

            if healthConnected && isCloudProviderSelected {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .frame(width: 28)
                    Text("Con un provider cloud attivo, i riepiloghi Health richiesti in chat possono essere inviati al provider selezionato insieme al contesto della conversazione.")
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !healthConnected {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.bobbyCaramel)
                        .frame(width: 28)
                    Text("Bobby può leggere frequenza cardiaca, HRV, passi, sonno, allenamenti e VO2 Max per analizzare il tuo stato fisico.")
                        .font(.caption)
                        .foregroundColor(.bobbyWarmGray)
                }
            }
        } header: {
            Label("Salute", systemImage: "heart.text.clipboard")
                .foregroundColor(.bobbyRed)
        } footer: {
            if healthConnected {
                Text("I dati vengono letti in sola lettura. Per revocare l'accesso vai in Impostazioni > Salute > Accesso Dati. Usa il provider Locale se vuoi evitare invii a provider cloud.")
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
            return aiSettings.isLocalAvailable ? "Modello locale attivo" : "Fallback locale gratuito"
        case .openai:
            return aiSettings.hasOpenAIKey ? "OpenAI \(aiSettings.openAIModel)" : "API Key mancante"
        case .anthropic:
            return aiSettings.hasAnthropicKey ? "Anthropic \(aiSettings.anthropicModel)" : "API Key mancante"
        case .openrouter:
            return aiSettings.hasOpenRouterKey ? "OpenRouter \(aiSettings.openRouterModel)" : "API Key mancante"
        case .auto:
            if aiSettings.isLocalAvailable {
                return "Locale (con fallback cloud)"
            } else if aiSettings.hasAnthropicKey {
                return "Anthropic \(aiSettings.anthropicModel)"
            } else if aiSettings.hasOpenAIKey {
                return "OpenAI \(aiSettings.openAIModel)"
            } else if aiSettings.hasOpenRouterKey {
                return "OpenRouter \(aiSettings.openRouterModel)"
            } else {
                return "Fallback locale gratuito"
            }
        }
    }

    private var isCloudProviderSelected: Bool {
        switch aiSettings.providerType {
        case .openai:
            return aiSettings.hasOpenAIKey
        case .anthropic:
            return aiSettings.hasAnthropicKey
        case .openrouter:
            return aiSettings.hasOpenRouterKey
        case .auto:
            return !aiSettings.isLocalAvailable && (aiSettings.hasAnthropicKey || aiSettings.hasOpenAIKey || aiSettings.hasOpenRouterKey)
        case .local:
            return false
        }
    }

    private func providerDescription(for type: LLMProviderType) -> String {
        switch type {
        case .local: return "Modello on-device o fallback gratuito"
        case .openai: return "Cloud OpenAI con API key utente"
        case .anthropic: return "Cloud Anthropic con API key utente"
        case .openrouter: return "Router cloud con API key utente"
        case .auto: return "Locale se disponibile; altrimenti cloud configurato"
        }
    }

    private func cloudDisclosureRow(provider: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.bobbyCaramel)
                .frame(width: 28)

            Text("Quando \(provider) è attivo, chat, profilo runner, piani e riepiloghi Apple Health necessari possono essere inviati al provider selezionato per generare la risposta.")
                .font(.caption)
                .foregroundColor(.bobbyWarmGray)
                .fixedSize(horizontal: false, vertical: true)
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
        if !openRouterKeyInput.isEmpty {
            aiSettings.openRouterAPIKey = openRouterKeyInput
        } else {
            aiSettings.openRouterAPIKey = nil
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

    private func validateOpenRouterKey() {
        isValidatingOpenRouter = true
        openRouterValidationMessage = ""

        Task {
            do {
                let provider = OpenRouterProvider(apiKey: openRouterKeyInput, model: aiSettings.openRouterModel)
                try await provider.validateKey()

                await MainActor.run {
                    isValidatingOpenRouter = false
                    openRouterKeyValidated = true
                    openRouterValidationMessage = "Connessione riuscita!"
                }
            } catch {
                await MainActor.run {
                    isValidatingOpenRouter = false
                    openRouterKeyValidated = false
                    openRouterValidationMessage = parseAPIError(error)
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
            return "Credito o quota non disponibile per questa API key."
        } else if message.contains("403") {
            return "Accesso negato. Verifica i permessi della tua API key."
        } else if message.contains("timeout") || message.contains("Timeout") {
            return "Timeout di connessione. Verifica la tua connessione internet."
        }
        return "Errore di connessione o validazione. Riprova e verifica configurazione e rete."
    }
}
