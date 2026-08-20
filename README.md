<p align="center">
  <img src="./run_wall_bobby.png" alt="Run with Bobby — corsa nel parco" width="100%">
</p>

# Run with Bobby 🏃‍♂️

**Il tuo personal trainer di corsa con AI locale su iPhone**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Repository](https://img.shields.io/badge/GitHub-run--with--bobby-181717?logo=github)](https://github.com/bobby-lagotto/run-with-bobby)

Progetto open source di [Francesco Saverio Mazzi](https://frasma.org) — [francemazzi@gmail.com](mailto:francemazzi@gmail.com)

## 🎯 Caratteristiche Principali

- **Chat conversazionale** con Bobby, il tuo coach AI specializzato nella corsa
- **Piani di allenamento personalizzati** basati sui tuoi obiettivi e livello
- **Oggi**: seduta del giorno, briefing di recupero e aderenza settimanale
- **HealthKit** per recupero e matching delle corse (lettura; scrittura workout solo se registri una seduta)
- **AI locale con MLX** e provider cloud opzionali con API key utente
- **Archivio piani** per salvare e ottimizzare i tuoi allenamenti
- **Interfaccia moderna** con SwiftUI e supporto Dark Mode

## 🚀 Come Iniziare

1. **Primo Avvio**: Segui la procedura di benvenuto per configurare il tuo profilo runner
2. **Chat con Bobby**: Racconta i tuoi obiettivi, chilometri settimanali e esperienza
3. **Ricevi il Piano**: Bobby genererà un piano personalizzato per te
4. **Ottimizza**: Chiedi modifiche e miglioramenti al tuo piano
5. **Salva nell'Archivio**: Tutti i piani vengono automaticamente salvati

## 📋 Esempi di Conversazione

### Setup Iniziale
```
Tu: "Ciao Bobby, corro circa 25km alla settimana e vorrei migliorare la mia velocità sui 10K"

Bobby: "Perfetto! Per creare il piano ideale dimmi:
• Quanti allenamenti fai alla settimana?
• Qual è il tuo ritmo attuale?
• Hai già corso gare di 10K?"
```

### Richiesta Piano
```
Tu: "Crea un piano per migliorare la velocità, 4 allenamenti/settimana"

Bobby: "⚡ PIANO FOCUS VELOCITÀ
MARTEDÌ — Interval Training · 11km
Riscaldamento: 2km facili
Lavoro: 6 × 1000m a 4:35-4:45/km
..."
```

### Ottimizzazione
```
Tu: "Il piano è troppo intenso, riduci il volume"

Bobby: "Ho ottimizzato il tuo piano riducendo del 10% le distanze. 
Ecco la versione aggiornata..."
```

## 🛠 Requisiti Tecnici

- **iOS 17.0+**
- **iPhone** (ottimizzato per MLX)
- **Spazio**: ~500MB per l'app + modelli AI
- **RAM**: Minimo 3GB consigliati per prestazioni ottimali

## 🧠 Integrazione MLX

L'app utilizza **MLX Swift** (fork PrismML per i kernel 1-bit) per l'inferenza locale:

- Qwen 2.5 Instruct 4-bit (0.5B / 1.5B / 3B) come default
- Bonsai MLX opzionali: Ternary 4B (2-bit), Bonsai 8B 1-bit, Bonsai 27B 1-bit (iPhone 17 Pro / Pro Max)
- Zero latenza di rete
- Privacy locale quando usi il modello on-device; se abiliti OpenAI, Anthropic o OpenRouter, chat, profilo runner e riepiloghi Health necessari possono essere inviati al provider selezionato
- Funziona anche offline

## 📁 Struttura del Progetto

```
RunWithBobby/
├── Models.swift              # Modelli dati (Chat, Piani, Profilo)
├── BobbyAI.swift            # Logica AI e MLX
├── TrainingPlanManager.swift # Gestione archivio piani
├── ChatView.swift           # Interfaccia chat principale
├── ContentView.swift        # Vista principale e welcome
└── RunWithBobbyApp.swift    # Entry point app
```

## 🎮 Funzionalità Avanzate

### Tipi di Allenamento Supportati
- **Corsa Facile** 🚶‍♂️ - Base aerobica
- **Interval Training** ⚡ - Lavoro di velocità
- **Tempo Run** 🏃‍♂️ - Soglia anaerobica  
- **Lungo** 💪 - Resistenza
- **Recupero** 🌱 - Rigenerazione
- **Riposo** 🛌 - Recupero completo

### Obiettivi Supportati
- Migliorare velocità
- Aumentare resistenza  
- Mantenersi in forma
- Perdere peso
- Preparazione gara

## 📊 Archivio e Statistiche

- **Salvataggio automatico** di tutti i piani generati
- **Piano attivo** sempre accessibile
- **Statistiche settimanali** (km totali, tempo, distribuzione allenamenti)
- **Export/Import** piani in formato JSON
- **Cronologia progressi** per monitorare miglioramenti

## 🔧 Configurazione Sviluppo

### Installazione
```bash
git clone https://github.com/bobby-lagotto/run-with-bobby.git
cd run-with-bobby
open RunWithBobby.xcodeproj
```

Repository: https://github.com/bobby-lagotto/run-with-bobby  
Supporto: https://github.com/bobby-lagotto/run-with-bobby/issues

### Dipendenze
- **MLX Swift**: Framework per AI locale
- **SwiftUI**: Interface moderna
- **Foundation**: Gestione dati e persistenza

### Build
1. Assicurati di avere **Xcode 15.0+**
2. Configura il **Team ID** nelle impostazioni di signing
3. Build per dispositivo fisico (MLX richiede hardware reale)

### Privacy e segreti
- Consulta [`PRIVACY_AND_SECURITY.md`](PRIVACY_AND_SECURITY.md) per la mappa dei dati sensibili.
- Le API key utente sono salvate nel Keychain; `.env` e `.env.local` restano locali e ignorati da git.
- Prima di una release esegui `scripts/scan-secrets.sh`.
- La modalità locale non invia dati ai provider cloud. I provider OpenAI, Anthropic e OpenRouter sono opzionali e ricevono solo il contesto necessario quando selezionati.

## 🤝 Contributi

Run with Bobby è software libero (GPL-3.0). Pull request e issue sono benvenuti su GitHub.

La roadmap prodotto (abitudine quotidiana, test, widget, Watch) è in [`ROADMAP.md`](ROADMAP.md).
La checklist modelli MLX on-device resta in [`DEVELOPMENT.md`](DEVELOPMENT.md).

## 🐛 Troubleshooting

### L'AI non risponde
- Verifica che il dispositivo abbia almeno 3GB di RAM liberi
- Riavvia l'app se MLX non si carica correttamente

### Piani non vengono salvati  
- Controlla i permessi di scrittura nell'app
- Verifica spazio disponibile su dispositivo

### Performance lente
- Chiudi altre app pesanti
- L'AI locale richiede risorse significative

## 📄 Licenza

Copyright (C) 2026 [Francesco Saverio Mazzi](https://frasma.org) — [francemazzi@gmail.com](mailto:francemazzi@gmail.com)

Distribuito sotto [GNU General Public License v3.0](LICENSE). Vedi anche [NOTICE](NOTICE) per le dipendenze di terze parti.

---

**Run with Bobby** — [frasma.org](https://frasma.org)

*Buona corsa! 🏃‍♂️💨*