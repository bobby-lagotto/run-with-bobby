# App Store Connect — listing pubblica

Copia questi campi in App Store Connect per la scheda pubblica di **Run with Bobby** (`com.runwithbobby.app`, adamId `6761195463`).

Versione binario da inviare: **1.5.4 (10)**. Note review e Resolution Center: [`AppStoreConnect-1.5.4.md`](AppStoreConnect-1.5.4.md).

## Informazioni app

- Nome: `Run with Bobby`
- Sottotitolo (30 caratteri): `Coach di corsa AI locale`
- Categoria primaria: Health & Fitness
- Categoria secondaria: Sports
- Prezzo: Gratis
- Privacy Policy URL (IT): https://bobby-lagotto.github.io/run-with-bobby/privacy.html
- Privacy Policy URL (EN): https://bobby-lagotto.github.io/run-with-bobby/en/privacy.html
- Support URL: https://github.com/bobby-lagotto/run-with-bobby/issues
- Marketing URL (IT): https://bobby-lagotto.github.io/run-with-bobby/
- Marketing URL (EN): https://bobby-lagotto.github.io/run-with-bobby/en/
- Copyright: `2026 Francesco Saverio Mazzi`

La landing GitHub Pages (hero Wimmelbild, screenshot, privacy) sta in `docs/` e, perché Pages è su `master` / `/` (root), anche in `index.html` / `privacy.html` / `en/` alla root. Se in Settings → Pages imposti folder `/docs`, gli URL restano gli stessi e le copie in root si possono togliere. In App Store Connect, localizza l’URL privacy in inglese sulla pagina EN.

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

## Novità 1.5.3

- Coach più preciso: salute, oggi, piani e aderenza dai tool/HealthKit, senza inventare km o HRV.
- Modello locale: niente più rifiuti «privacy/legali» al posto del coaching.
- Conferma esplicita prima di salvare o ottimizzare un piano.

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

In **Informazioni sull’app** (non nella pagina versione) → Classificazione per età:

- Made for Kids / Per bambini: **No**
- Violenza, sesso, linguaggio, orrore, alcol, gioco d’azzardo, web illimitato: **Nessuno**
- Informazioni mediche/trattamenti: **Infrequente/Lieve** (briefing recupero e HealthKit)
- UGC pubblico: **No**

Esito atteso: 4+ o 12+ a seconda del questionario Apple.

## Categoria

**Informazioni sull’app** → Categoria primaria: **Salute e fitness**. Secondaria: **Sport**.

## Prezzi e disponibilità

Sidebar **Prezzi e disponibilità**:

- Prezzo **Gratis** (0) sui paesi in cui l’app è in vendita. Nessun IAP.
- **China mainland deselezionato.** Hong Kong e Macao restano. Non usare “tutti i paesi”: i metadata citano OpenAI e Apple respinge Guideline 5 se la Cina continentale è inclusa (1.5.3 (8), 15 settembre 2026).
- I metadata possono citare OpenAI / Anthropic / OpenRouter **solo** se China mainland è fuori. Per vendere in Cina servirebbero altro percorso (geo-block + scrub metadata + licenza MIIT), fuori scope.

## App Privacy (etichette)

Sidebar **Privacy dell’app** (serve il ruolo Account Holder / Admin):

1. Incolla l’URL privacy IT: `https://bobby-lagotto.github.io/run-with-bobby/privacy.html`. Per la localizzazione inglese: `https://bobby-lagotto.github.io/run-with-bobby/en/privacy.html`.
2. Tracking: **No**
3. Dati raccolti: dichiara ciò che **può uscire** dal telefono con cloud opzionale:
   - Health & Fitness
   - Other User Content (chat)
   - Scopo: App Functionality
   - Linked to identity: **No**
   - Used for tracking: **No**
4. Non dichiarare come “raccolti dal developer” i JSON che restano solo on-device in modalità Locale.

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` (solo HTTPS standard). In App Store Connect rispondi che usi solo encryption esente.

## App Privacy

Allineata a `PRIVACY_AND_SECURITY.md`:

- Tracking: no
- Dati raccolti: Health & Fitness, Other User Content — usati per App Functionality, not linked, not used for tracking
- HealthKit: lettura on-demand; scrittura workout solo se l’utente registra una seduta
- Provider cloud opzionali: se selezionati possono ricevere chat, profilo runner e riepiloghi Health necessari alla risposta

## Note per la review

Incolla in testa (inglese, per il reviewer):

```
China mainland storefront is deselected. Run with Bobby is not distributed in mainland China.

Optional OpenAI / Anthropic / OpenRouter remain available only outside China, and only if the user pastes their own API key. There is no ChatGPT or Claude.ai consumer login. Default coaching is on-device (MLX).
```

Poi il resto:

Run with Bobby è gratuita. Il coaching locale resta disponibile senza acquisti, senza StoreKit e senza paywall. I provider cloud sono opzionali e funzionano solo con API key già possedute dall’utente, salvate nel Keychain. L’app non usa login consumer Claude.ai o ChatGPT.

Apple Health: lettura di metriche di recupero e allenamento per personalizzare il briefing. L’app scrive un workout in Salute solo se l’utente registra una seduta di corsa. In modalità Locale questi dati non escono dal dispositivo. Quando un provider cloud è selezionato, chat, profilo runner e i riepiloghi Health necessari possono essere inviati al provider scelto per generare la risposta.

Account demo: non richiesto. Al primo avvio si può saltare il profilo e parlare con Bobby; il profilo si compila dal foglio Profilo. Per l’AI locale scaricare un modello dalla schermata Impostazioni AI (consigliato Qwen 2.5 1.5B). L’inferenza MLX non gira sul simulatore: testare su iPhone fisico.

Open source: https://github.com/bobby-lagotto/run-with-bobby

## Risposta al messaggio Apple (Guideline 5)

Thread Messaggi della submission `ec406992-4537-4119-869a-98cc584a1b8e`:

```
Hello,

China mainland has been deselected in App Availability. Run with Bobby is not distributed in mainland China.

Optional OpenAI / Anthropic / OpenRouter stay available only outside China, and only if the user pastes their own API key. There is no ChatGPT consumer login. We are resubmitting the same build 1.5.3 (8).

Thank you.
```

## Checklist prima di Submit for Review

1. Esegui `scripts/scan-secrets.sh`.
2. In Apple Developer, App ID `com.runwithbobby.app`: HealthKit, App Groups `group.com.runwithbobby.app`, Increased Memory Limit.
3. Archive Release e upload con `ExportOptions-upload.plist` (comandi in `DEVELOPMENT.md`). Per questo resubmit Guideline 5: **salta l’archive**, usa la build **8** già caricata.
4. Seleziona la build **8** sulla versione 1.5.3. Non cambiare nome, sottotitolo, descrizione, screenshot, keyword.
5. Carica gli 8 PNG 6.5" (slot di default) da `AppStore/screenshots/iphone-6.5/` se non sono già in scheda.
6. Informazioni sull’app: categoria + classificazioni.
7. Privacy dell’app: URL Pages + etichette.
8. Prezzi: Gratis. **Availability: China mainland deselezionato** (obbligatorio se i metadata citano OpenAI).
9. Review Notes: conferma EN che la Cina continentale è esclusa (vedi sopra).
10. Rispondi al thread Messaggi Apple, poi Submit for Review / Invia di nuovo.

Da questo repository non si può cliccare Submit: servono le credenziali App Store Connect.
