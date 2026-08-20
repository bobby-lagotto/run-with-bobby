# Roadmap — da piano ad abitudine

Allinea Run with Bobby al [RFS YC](https://www.ycombinator.com/rfs) *AI-Powered Consumer Products for 1 Billion People*: un coach che torna ogni giorno, legge il corpo, adatta il piano e può restare on-device.

Questa è l'unica lista di lavoro prodotto. La checklist MLX on-device (Qwen/Bonsai) resta in [`DEVELOPMENT.md`](DEVELOPMENT.md) e non si fonde con queste fasi.

## North star

Bobby non è un generatore di PDF settimanali. È un agente da home screen: sa cosa c'è in programma oggi, se hai corso, come hai dormito, e ti dice il prossimo passo — anche senza rete.

```
piano attivo → seduta di oggi → briefing salute → notifica
       ↑                                              ↓
  adatta piano ← aderenza ← registro / GPS / HealthKit
```

## Baseline (già fatto)

- Chat con tool-calling, profilo runner, piani settimanali, nutrizione
- HealthKit in lettura (`get_health_summary`) e consenso cloud
- MLX on-device + OpenAI / Anthropic / OpenRouter opzionali
- Persistenza locale protetta (`SensitiveDataStore`)
- Welcome informativo: **non** raccoglie il profilo (si compila dal foglio Profilo)
- iOS **17.0**
- Hook già presenti, non da reimplementare: `exportPlan` / `importPlan`, `getPlanTrends()` (backend senza UI)
- Codice morto da non toccare: `extractTrainingPlan()`, `autoUpdateNutritionPlan()`

## Protocollo

1. Prima di una fase: checkbox **In corso**, data.
2. Implementare solo i criteri di done di quella fase.
3. Aggiungere o estendere test in `RunWithBobbyTests/` e lanciarli sul simulatore.
4. Se i test passano: spuntare, annotare comando + esito, file toccati, sbloccare la fase successiva.
5. Se falliscono: non spuntare; nota su cosa è rotto.

Non si apre la fase N+1 se la N non è verde.

I test sono **logica pura** (tool, matching, briefing, aderenza, snapshot). Niente inferenza MLX in CI. HealthKit è finto.

### Come lanciare i test

```bash
xcodebuild test \
  -project RunWithBobby.xcodeproj \
  -scheme RunWithBobby \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Esito 2026-08-20: **15 test, 0 failure**.

Gate già usabili, non sostitutivi dei test di fase: `scripts/scan-secrets.sh`, `scripts/verify-bonsai-catalog.sh`.

## Fuori scope

The Primer, aging, multiplayer, defense, crypto, App Store listing, paywall, modelli MLX custom. Il local-first è un vincolo (Oggi e notifiche funzionano senza cloud), non una fase a sé.

---

## Fase 0 — Metodo

Obiettivo: poter testare l'app sul simulatore e avere un solo `AppState`.

File: `RunWithBobby.xcodeproj`, `RunWithBobbyTests/`, `ChatView.swift`, `RunWithBobbyApp.swift`, `TrainingPlanManager.swift`, `README.md`, `DEVELOPMENT.md`

Test: `ToolRouterIntegrationTests` — `calculate_training_plan` + `save_training_plan` su directory temporanea.

### Checkbox

- [x] Target `RunWithBobbyTests` nel progetto Xcode
- [x] `TrainingPlanManager` accetta una directory base (test isolati)
- [x] Test baseline ToolRouter (calcola + salva piano attivo)
- [x] `ChatView` usa `EnvironmentObject` di `AppState`, non un `@StateObject` nuovo
- [x] Manager (piani, nutrizione, Health, AI) creati nell'app e iniettati
- [x] README: iOS 17, HealthKit già presente, link a questo file al posto di "Possibili Miglioramenti"
- [x] DEVELOPMENT: comando test + link a questa roadmap (checklist MLX intatta)

**In corso:** no
**Completata:** 2026-08-20 — `xcodebuild test` verde (incluso baseline ToolRouter).

---

## Fase 1 — Aderenza

Obiettivo: sapere se la seduta del giorno è prevista, fatta, parziale o saltata.

File: `Models.swift`, `Habit/`, `ToolRouter.swift`, `BobbyAI.swift`, `HealthKitManager.swift`, `ChatView.swift`

Test: `AdherenceIntegrationTests`

- mercoledì 8 km + workout 7.4 km → `partial`
- nessun workout → `planned`
- `get_adherence` restituisce percentuale e contesto coach

### Checkbox

- [x] `SessionStatus`: planned / completed / skipped / partial su `DayTraining` (JSON vecchi restano decodificabili)
- [x] Matching allenamenti Health (corsa/camminata) al giorno di piano
- [x] Soglia fatto ≥ 95% dei km previsti; sotto → parziale
- [x] Tool `get_adherence` e `log_session` (conferma esplicita, come i save)
- [x] Striscia "oggi" in chat e stato nel dettaglio piano
- [x] Test di integrazione verdi

**In corso:** no
**Completata:** 2026-08-20

---

## Fase 2 — Briefing e notifiche

Obiettivo: raccomandazione vai / facile / riposo **senza** chiamare l'LLM; promemoria locale della seduta.

File: `Habit/ReadinessEngine.swift`, `Habit/NotificationPlanning.swift`, `Habit/NotificationScheduler.swift`, `ToolRouter.swift`, `BobbyAI.swift`

Test: `ReadinessNotificationTests`

- HRV basso + sonno scarso → easy o rest
- dati ok + seduta qualità → go
- date notifiche calcolate (non `UNUserNotificationCenter` reale)

### Checkbox

- [x] `HealthSignals` + `ReadinessEngine` (sonno, HRV, FC riposo, tipo seduta)
- [x] Tool `get_today_briefing`
- [x] System prompt: usarlo per "cosa faccio oggi?" / mattina
- [x] `NotificationPlanning` per le 7:00 locali dei giorni con seduta
- [x] Scheduler locale, nessun server
- [x] Test verdi

**In corso:** no
**Completata:** 2026-08-20

---

## Fase 3 — Superficie Oggi

Obiettivo: home che non aspetta MLX.

File: `Habit/TodayPresenter.swift`, `TodayView.swift`, `ContentView.swift`

Test: `TodayPresenterTests` — piano assente, giorno di riposo, seduta con aderenza.

### Checkbox

- [x] `TodayPresenter` da piano + aderenza + briefing
- [x] Tab/home Oggi: seduta, briefing, aderenza settimana, CTA (fatto / salta / parla con Bobby)
- [x] Funziona offline
- [x] Test verdi

**In corso:** no
**Completata:** 2026-08-20

---

## Fase 4 — Registro corsa

Obiettivo: loggare una seduta e confrontarla col previsto. GPS è un incremento, non un prodotto a parte.

File: `Habit/RunSessionLogic.swift`, `Habit/RunSessionController.swift`, `RunSessionView.swift`, `HealthKitManager.swift`

Test: `RunSessionLogicTests`

- previsto 10 km vs 10.1 → completed
- previsto 10 km vs 4 → partial + suggerimento `optimize_plan` **senza** applicarlo

### Checkbox

- [x] Confronto previsto vs loggato (stesse soglie della Fase 1)
- [x] Avvio/stop sessione (GPS se autorizzato) + log manuale
- [x] Aggiorna aderenza sul piano attivo
- [x] Scrittura workout HealthKit solo se autorizzati
- [x] Test verdi

**In corso:** no
**Completata:** 2026-08-20

---

## Fase 5 — Widget

Obiettivo: seduta di oggi sulla Home/Lock, stesso builder di Oggi.

File: `Habit/TodaySnapshot.swift`, `BobbyTodayWidget/`

Test: `TodaySnapshotTests` — payload senza dati Health extra.

### Checkbox

- [x] `TodaySnapshot` Codable, campi minimi
- [x] App Group `group.com.runwithbobby.app`, file protection
- [x] WidgetKit legge lo snapshot
- [x] Test verdi

**In corso:** no
**Completata:** 2026-08-20

---

## Fase 6 — Watch

Obiettivo: companion minimo. Target nuovo, in fondo perché serve poco senza Fase 1–3.

File: `BobbyWatch/`, stesso `TodaySnapshot`

Test: `TodaySnapshotTests` — encode/decode identico iPhone/Watch.

### Checkbox

- [x] App watchOS: oggi + fatto/salta (`BobbyWatch` + scheme dedicato)
- [x] Stesso codec snapshot
- [x] Test verdi

**Nota:** il target Watch **non è embedded** nell'app iOS. Su questa macchina `xcodebuild test` richiede watchOS 26.5 se Watch è embedded; lo scheme `BobbyWatch` resta autonomo. Ri-embed quando l'SDK Watch è installato.

**In corso:** no
**Completata:** 2026-08-20

---

## Changelog

- 2026-08-20 — Creato il file.
- 2026-08-20 — Fase 0 completata. Test: `ToolRouterIntegrationTests`. File: target test, `AppState` unificato, README/DEVELOPMENT.
- 2026-08-20 — Fase 1 completata. Test: `AdherenceIntegrationTests`. File: `Habit/AdherenceEngine.swift`, tool `get_adherence` / `log_session`.
- 2026-08-20 — Fase 2 completata. Test: `ReadinessNotificationTests`. File: `ReadinessEngine`, `NotificationPlanning`, tool `get_today_briefing`.
- 2026-08-20 — Fase 3 completata. Test: `TodayPresenterTests`. File: `TodayView.swift`, tab Oggi.
- 2026-08-20 — Fase 4 completata. Test: `RunSessionLogicTests`. File: `RunSessionView.swift`, scrittura HK workout.
- 2026-08-20 — Fase 5 completata. Test: `TodaySnapshotTests`. File: `BobbyTodayWidget/`.
- 2026-08-20 — Fase 6 completata. Test: codec snapshot. File: `BobbyWatch/` (scheme autonomo, non embedded).
- 2026-08-20 — `xcodebuild test` su iPhone 17 Simulator: 15 test, 0 failure.
