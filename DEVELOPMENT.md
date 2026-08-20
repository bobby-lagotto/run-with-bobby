# Run with Bobby - Guida Sviluppatore

## 🛠 Setup Ambiente di Sviluppo

### Requisiti
- **Xcode 15.0+** (con iOS 17 SDK)
- **macOS 14.0+** (per supporto MLX completo)
- **iPhone fisico** con iOS 16.0+ (MLX non funziona su simulatore)
- **Apple Developer Account** (per testing su device)

### Quick Start
```bash
# Clona e apri il progetto
git clone https://github.com/bobby-lagotto/run-with-bobby.git
cd run-with-bobby
chmod +x build.sh
./build.sh

# Apri in Xcode
open RunWithBobby.xcodeproj
```

## 📁 Architettura del Progetto

### Modelli di Dati (`Models.swift`)
```swift
- ChatMessage: Singolo messaggio nella chat
- Conversation: Conversazione completa con storico
- TrainingPlan: Piano di allenamento settimanale 
- RunnerProfile: Profilo utente (km/sett, obiettivi, livello)
- AppState: Stato globale dell'app con persistenza
```

### AI Engine (`BobbyAI.swift`)
```swift
- BobbyAI: Gestione MLX e generazione risposte
- generateResponse(): Logica principale conversazione
- extractTrainingPlan(): Parsing piani da testo
- MLX Integration: Caricamento modelli locali
```

### Piano Manager (`TrainingPlanManager.swift`)
```swift
- TrainingPlanManager: CRUD per piani allenamento
- WeeklyStats: Statistiche settimanali
- Plan Templates: Generazione template per obiettivi
- Export/Import: Gestione backup piani
```

### UI Views (`ChatView.swift`, `ContentView.swift`)
```swift
- ChatView: Interfaccia chat principale
- MessageBubbleView: Rendering messaggi
- TrainingPlanViews: Visualizzazione piani
- WelcomeView: Onboarding primo avvio
```

## 🧠 Integrazione MLX

L'inferenza on-device usa **MLX Swift LM** (`Vendor/mlx-swift-lm`, tag 2.31.3) puntato al fork PrismML di `mlx-swift` (branch `v0.31.3_prism`) per i kernel 1-bit di Bonsai. I Qwen 4-bit restano supportati. 2.31.3 registra `qwen3_5`, necessario per Bonsai 27B.

MLX **non funziona sul simulatore**: serve un iPhone fisico.

### Catalogo modelli (`LocalModelCatalog.swift`)

**Qwen 2.5 Instruct 4-bit** (default, tool-calling più affidabile):

- `mlx-community/Qwen2.5-0.5B-Instruct-4bit` — ~400 MB, 4 GB RAM
- `mlx-community/Qwen2.5-1.5B-Instruct-4bit` — ~900 MB, 6 GB RAM (consigliato)
- `mlx-community/Qwen2.5-3B-Instruct-4bit` — ~1.9 GB, 8 GB RAM

**Bonsai MLX** (non GGUF):

- `prism-ml/Ternary-Bonsai-4B-mlx-2bit` — ~1.1 GB, 6 GB RAM, 2-bit ternario
- `prism-ml/Bonsai-8B-mlx-1bit` — ~1.3 GB, 6 GB RAM, 1-bit
- `prism-ml/Bonsai-27B-mlx-1bit` — ~5.2 GB, iPhone 17 Pro / Pro Max (12 GB). `model_type=qwen3_5` (Qwen3.5 hybrid). mlx-swift-lm 2.31.3 lo registra; il load on-device resta da verificare su Pro Max.

Il contesto KV è limitato a 2048 token (`GenerateParameters.maxKVSize`). Il 27B usa anche KV 4-bit.

### Test on-device (ordine)

1. Build su device fisico (MLX non gira sul simulatore).
2. Regression Qwen 1.5B: chat in italiano + tool `calculate_training_plan`.
3. Ternary Bonsai 4B: download, generazione, piano + conferma save.
4. Bonsai 8B 1-bit: stesso protocollo (se i kernel 1-bit mancano, il load fallisce qui).
5. Bonsai 27B: solo iPhone 17 Pro / Pro Max; chat breve e un tool round-trip. Osservare jetsam e termico. Non deve diventare il modello consigliato.

Verifica catalogo HuggingFace (senza device): `scripts/verify-bonsai-catalog.sh`.

Stato già verificato in sviluppo: `xcodebuild` iOS generic **BUILD SUCCEEDED** con fork PrismML `v0.31.3_prism`; i `config.json` HF confermano Qwen2 (Qwen 1.5B), Qwen3 2-bit/1-bit (Ternary 4B, Bonsai 8B) e `qwen3_5` 1-bit (Bonsai 27B). Nessun iPhone fisico collegato al momento del merge: i passi 2–5 restano da fare sul device.

### Dipendenze SPM

Il progetto Xcode usa il package locale `Vendor/mlx-swift-lm`, che scarica `PrismML-Eng/mlx-swift` da GitHub. Non aggiungere anche `ml-explore/mlx-swift`: conflitto di identità SPM.

Per Bonsai 27B l'app dichiara `com.apple.developer.kernel.increased-memory-limit`. Abilita la capability **Increased Memory Limit** sull'App ID in Apple Developer, altrimenti il profilo di provisioning può rifiutare la firma.

## 💾 Persistenza Dati

### Struttura Directory
```
Documents/
├── conversations.json          # Chat storiche
├── training_plans.json         # Archivio piani 
├── user_profile.json          # Profilo utente
├── active_plan.json           # Piano corrente attivo
└── TrainingPlans/             # Directory piani individuali
    ├── {uuid}.json
    └── ...
```

### Backup e Restore
```swift
// Export completo dati utente
func exportUserData() -> URL? {
    // Crea backup completo di conversazioni + piani + profilo
}

// Import da backup
func importUserData(from url: URL) -> Bool {
    // Ripristina stato completo dell'app
}
```

### Protezione dati locali
- Usa `SensitiveDataStore.write` per ogni JSON che contiene chat, profilo, piani allenamento o piani alimentari.
- I file sensibili devono usare file protection completa ed essere esclusi da backup quando non servono fuori dispositivo.
- Usa `PrivacyLog` per log di debug redatti; non stampare payload Health, prompt, risposte provider o API key.

## 🎨 UI/UX Guidelines

### Design System
- **Colori**: AccentColor definito in Assets.xcassets
- **Tipografia**: SF Pro (system font) con scale dinamiche
- **Icone**: SF Symbols + emoji per workout types
- **Spacing**: Multipli di 8pt per consistency

### Accessibilità
```swift
// Implementare in tutti i componenti
.accessibilityLabel("Piano di allenamento settimanale")
.accessibilityHint("Tocca per visualizzare dettagli")
.accessibilityAction(.activate) { /* azione */ }
```

### Dark Mode
- Testare tutti i componenti in entrambe le modalità
- Usare colori semantici (`.primary`, `.secondary`)
- AccentColor ha varianti per light/dark mode

## Test di integrazione (simulatore)

I test dell'app stanno in `RunWithBobbyTests/` e coprono tool, aderenza, briefing e snapshot. Non lanciano MLX.

```bash
xcodebuild test \
  -project RunWithBobby.xcodeproj \
  -scheme RunWithBobby \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

La roadmap prodotto e il protocollo fase-per-fase sono in [`ROADMAP.md`](ROADMAP.md). Questa sezione MLX on-device resta la checklist modelli.

## 🧪 Testing Strategy

I test automatici sono quelli in `RunWithBobbyTests`. I test UI e performance MLX restano manuali sul device.

## 🚀 Deployment

### App Store Build
```bash
# Build release firmato
xcodebuild archive \
    -project RunWithBobby.xcodeproj \
    -scheme RunWithBobby \
    -archivePath "./RunWithBobby.xcarchive" \
    -configuration Release
    
# Upload ad App Store Connect
xcodebuild -exportArchive \
    -archivePath "./RunWithBobby.xcarchive" \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath "./Release"
```

### Privacy/Security  
- **MLX Locale**: Enfatizza che l'AI locale non invia dati online
- **Provider Cloud**: dichiara che OpenAI, Anthropic e OpenRouter sono opzionali e possono ricevere chat, profilo, piani e riepiloghi Health necessari
- **Data Protection**: usa `SensitiveDataStore` per JSON sensibili
- **Secret Scan**: esegui `scripts/scan-secrets.sh` prima di release/CI
- **App Tracking**: Dichiara utilizzo zero di tracking
- **Privacy Policy**: Includi policy per App Store review

## 🔧 Troubleshooting Sviluppo

### Errori Comuni MLX
```
Error: "MLX not available on simulator"
Fix: Testa sempre su dispositivo fisico

Error: "Model loading failed - insufficient memory"  
Fix: Chiudi altre app, usa modello più piccolo

Error: "Metal framework not found"
Fix: Verifica target iOS 16.0+ e device supportato
```

### Build Issues
```
Error: "Package MLX-Swift not found"
Fix: Run xcodebuild -resolvePackageDependencies

Error: "Code signing failed"
Fix: Configura Team ID nelle build settings

Error: "Swift version mismatch"
Fix: Imposta SWIFT_VERSION = 5.0 nel progetto
```

## Roadmap prodotto

Vedi [`ROADMAP.md`](ROADMAP.md). Non duplicare checkbox qui.

## 🤝 Contributi

### Code Style
- SwiftLint configuration in `.swiftlint.yml`
- Commenti dettagliati per logica MLX/AI
- Naming convention: `camelCase` per properties, `PascalCase` per types

### Pull Request Process
1. Fork https://github.com/bobby-lagotto/run-with-bobby
2. Create feature branch: `feature/[nome-funzionalita]`
3. Test su dispositivo fisico
4. Update documentation se necessario
5. Submit PR con description dettagliata

---

**Happy Coding! 👨‍💻🏃‍♂️**