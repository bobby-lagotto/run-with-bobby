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

### Modelli Supportati
L'app è progettata per modelli leggeri ottimizzati per iPhone:

```swift
// Modelli consigliati (placeholder - da implementare)
- phi-3-mini-4k: ~2.3GB, ottimo per iPhone 12+
- llama-3.2-1b: ~1.2GB, funziona su iPhone 11+  
- qwen2.5-0.5b: ~600MB, compatibile con iPhone XS+
```

### Configurazione MLX
```swift
// In BobbyAI.swift - loadModel()
private func loadMLXModel() async throws -> MLXModel {
    // Carica modello da bundle app o download
    let modelURL = Bundle.main.url(forResource: "phi-3-mini", withExtension: "safetensors")
    return try await MLX.loadModel(from: modelURL)
}
```

### Performance Optimization
- **Memory Management**: Libera modello quando app va in background
- **Batch Processing**: Processa più richieste insieme se possibile
- **Caching**: Cache di risposte comuni per ridurre inferenza
- **Quantization**: Usa modelli quantizzati INT8 per memoria ridotta

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

## 🧪 Testing Strategy

### Unit Tests
```swift
// Test logica core
- BobbyAI response generation
- TrainingPlan parsing e validation  
- RunnerProfile calculations
- Data persistence round-trip
```

### UI Tests
```swift
// Test flussi utente critici
- Onboarding primo avvio
- Creazione piano di allenamento
- Salvataggio e recupero conversazioni
- Ottimizzazione piani esistenti
```

### Performance Tests  
```swift
// Test prestazioni MLX
- Tempo caricamento modello
- Latenza generazione risposta
- Memory usage durante inferenza
- Battery impact measurement
```

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

## 📈 Roadmap Funzionalità

### v1.1 - Health Integration
- [ ] HealthKit per tracking corse reali
- [ ] Confronto piano vs prestazioni effettive  
- [ ] Suggerimenti basati su dati biometrici

### v1.2 - Social Features
- [ ] Condivisione piani con altri runner
- [ ] Community di piani pubblici
- [ ] Sfide e obiettivi condivisi

### v1.3 - Advanced AI
- [ ] Modelli MLX personalizzati pre-addestrati  
- [ ] Analisi video tecnica di corsa
- [ ] Previsione performance e tempi gara

### v2.0 - Ecosystem
- [ ] Apple Watch companion app
- [ ] iPad version con grafici avanzati
- [ ] macOS version per coaching professionale

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