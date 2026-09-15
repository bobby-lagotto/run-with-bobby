# App Store Connect — listing pubblica

Copia questi campi in App Store Connect per la scheda pubblica di **Run with Bobby** (`com.runwithbobby.app`, adamId `6761195463`).

Versione binario da caricare: **1.5.2 (5)** — la build 4 in TestFlight è precedente a display name, iPhone-only e capability attuali.

## Informazioni app

- Nome: `Run with Bobby`
- Sottotitolo (30 caratteri): `Coach di corsa AI locale`
- Categoria primaria: Health & Fitness
- Categoria secondaria: Sports
- Prezzo: Gratis
- Privacy Policy URL: https://github.com/bobby-lagotto/run-with-bobby/blob/master/PRIVACY_AND_SECURITY.md
- Support URL: https://github.com/bobby-lagotto/run-with-bobby/issues
- Marketing URL (opzionale): https://github.com/bobby-lagotto/run-with-bobby
- Copyright: `2026 Francesco Saverio Mazzi`

Se Apple rifiuta l’URL GitHub della privacy policy, pubblica lo stesso testo su una pagina HTTPS stabile (es. frasma.org).

## Testo promozionale (170 caratteri)

Il coach di corsa vive sul tuo iPhone, non nel cloud. Piani, Oggi e HealthKit in locale. Gratis, senza abbonamento. Cloud solo se lo scegli tu.

## Descrizione

Il personal trainer è in tasca. Non in un abbonamento, non in una chat nel browser: sul tuo iPhone.

Bobby è un agente AI di corsa che gira in locale. Gli parli in italiano, gli dici i km e l’obiettivo, e lui costruisce la settimana: facile, interval, tempo, lungo, recupero. Ogni giorno la tab Oggi ti dice cosa fare, se recuperare, e quanto stai rispettando il piano — anche senza rete, dopo aver scaricato il modello.

Perché è diverso
• Default locale: chat, profilo e piani restano sul telefono
• Zero abbonamento, zero paywall, zero API key obbligatorie
• HealthKit per recupero e matching delle corse; un workout va in Salute solo se registri tu la seduta
• Cloud (OpenAI, Anthropic, OpenRouter) solo se incolli una tua chiave: è un extra, non il prodotto

Cosa fai con Bobby
• Una chat di coaching, con conferma prima di salvare qualsiasi piano
• Piani per 5K, 10K, mezza o semplicemente “stare in forma”
• Piano alimentare collegato agli allenamenti
• Archivio dei piani, widget Oggi, registrazione della seduta

Requisiti: iPhone, iOS 17 o successivo. Il modello locale occupa spazio e RAM (meglio almeno 3 GB liberi).

Software libero (GPL-3.0): https://github.com/bobby-lagotto/run-with-bobby

## Keyword (100 caratteri)

corsa,running,coach,allenamento,privacy,offline,5K,10K,maratona,fitness,nutrizione,AI,locale

## Novità 1.5.2

- Fix selezione modelli locali in Impostazioni AI: il tap sulla riga aggiorna il modello attivo.
- Tap su un modello non scaricato avvia il download dalla riga.
- Correzione persistenza dei modelli scaricati tra un avvio e l’altro.

## Screenshot

La scheda di default in App Store Connect mostra lo slot **iPhone 6,5"** (`1284 × 2778`). Usa i PNG in `AppStore/screenshots/iphone-6.5/`.

Per lo slot 6.9" (`1320 × 2868`): **Visualizza tutte le dimensioni in Gestione risorse multimediali** → iPhone 6.9", file in `AppStore/screenshots/iphone-6.9/`.

Ordine in entrambi i set:

1. `01-coach-locale.png`
2. `02-privacy.png`
3. `03-offline.png`
4. `04-gratis.png`
5. `05-salute.png`
6. `06-chat.png`
7. `07-oggi.png`
8. `08-piani.png`

PNG RGB senza alpha. Non caricare set iPad: il binario è iPhone-only. Non caricare screenshot Watch.

Per rigenerare le illustrazioni:

```bash
python3 scripts/compose_appstore_screenshots.py
```

Per catturare Chat, Oggi e Archivio dal simulatore (DEBUG, launch argument `-AppStoreScreenshots`):

```bash
scripts/capture_appstore_ui.sh
```

## Age rating

4+ (nessun contenuto riservato). Health & Fitness, niente UGC pubblico, niente gambling.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` (solo HTTPS standard). In App Store Connect rispondi che usi solo encryption esente.

## App Privacy

Allineata a `PRIVACY_AND_SECURITY.md`:

- Tracking: no
- Dati raccolti: Health & Fitness, Other User Content — usati per App Functionality, not linked, not used for tracking
- HealthKit: lettura on-demand; scrittura workout solo se l’utente registra una seduta
- Provider cloud opzionali: se selezionati possono ricevere chat, profilo runner e riepiloghi Health necessari alla risposta

## Note per la review

Run with Bobby è gratuita. Il coaching locale resta disponibile senza acquisti, senza StoreKit e senza paywall. I provider cloud sono opzionali e funzionano solo con API key già possedute dall’utente, salvate nel Keychain. L’app non usa login consumer Claude.ai o ChatGPT.

Apple Health: lettura di metriche di recupero e allenamento per personalizzare il briefing. L’app scrive un workout in Salute solo se l’utente registra una seduta di corsa. In modalità Locale questi dati non escono dal dispositivo. Quando un provider cloud è selezionato, chat, profilo runner e i riepiloghi Health necessari possono essere inviati al provider scelto per generare la risposta.

Account demo: non richiesto. Al primo avvio si può saltare il profilo e parlare con Bobby; il profilo si compila dal foglio Profilo. Per l’AI locale scaricare un modello dalla schermata Impostazioni AI (consigliato Qwen 2.5 1.5B). L’inferenza MLX non gira sul simulatore: testare su iPhone fisico.

Open source: https://github.com/bobby-lagotto/run-with-bobby

## Checklist prima di Submit for Review

1. Esegui `scripts/scan-secrets.sh`.
2. In Apple Developer, App ID `com.runwithbobby.app`: HealthKit, App Groups `group.com.runwithbobby.app`, Increased Memory Limit.
3. Archive Release e upload con `ExportOptions-upload.plist` (comandi in `DEVELOPMENT.md`).
4. Seleziona la build 5 sulla versione 1.5.2.
5. Carica gli 8 PNG 6.9".
6. Incolla descrizione, keyword, note review e URL.
7. Conferma questionario App Privacy e encryption.
8. Submit for Review.

Da questo repository non si può cliccare Submit: servono le credenziali App Store Connect.
