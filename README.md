# Run with Bobby 🏃‍♂️

**Il tuo personal trainer di corsa con AI locale su iPhone**

## 🎯 Caratteristiche Principali

- **Chat conversazionale** con Bobby, il tuo coach AI specializzato nella corsa
- **Piani di allenamento personalizzati** basati sui tuoi obiettivi e livello
- **AI completamente locale** utilizzando MLX - i tuoi dati non lasciano mai l'iPhone
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

- **iOS 16.0+**
- **iPhone** (ottimizzato per MLX)
- **Spazio**: ~500MB per l'app + modelli AI
- **RAM**: Minimo 3GB consigliati per prestazioni ottimali

## 🧠 Integrazione MLX

L'app utilizza **MLX Swift** di Apple per l'inferenza locale dei modelli AI:

- Modelli leggeri ottimizzati per mobile (phi-3-mini, llama-3.2-1b)
- Zero latenza di rete
- Privacy completa - nessun dato inviato online
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
git clone [repository]
cd run-with-bobby
open RunWithBobby.xcodeproj
```

### Dipendenze
- **MLX Swift**: Framework per AI locale
- **SwiftUI**: Interface moderna
- **Foundation**: Gestione dati e persistenza

### Build
1. Assicurati di avere **Xcode 15.0+**
2. Configura il **Team ID** nelle impostazioni di signing
3. Build per dispositivo fisico (MLX richiede hardware reale)

## 🤝 Contributi

Questo progetto è creato come dimostrazione delle capacità di OpenClaw/Claude Code. 

### Possibili Miglioramenti
- [ ] Integrazione HealthKit per dati reali di corsa
- [ ] Notifiche promemoria allenamenti
- [ ] Widget iOS per piano settimanale
- [ ] Apple Watch companion app
- [ ] Grafici avanzati prestazioni
- [ ] Modelli MLX personalizzati pre-addestrati
- [ ] Supporto per piani multi-settimana
- [ ] Integrazione GPS per tracking corse

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

Progetto dimostrativo creato con OpenClaw. Usa responsabilmente e rispetta i termini di utilizzo di MLX Swift.

---

**Creato con ❤️ da Bobby (Claude via OpenClaw)**

*Buona corsa! 🏃‍♂️💨*