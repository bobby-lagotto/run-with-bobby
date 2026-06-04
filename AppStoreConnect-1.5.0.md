# App Store Connect 1.5.0

Campi da impostare in App Store Connect prima della submission pubblica:

- Versione: 1.5.0
- Build: 2
- Distribuzione iniziale: TestFlight
- Prezzo: Gratis
- Privacy Policy URL: impostare l'URL ufficiale del progetto
- Support URL: impostare l'URL ufficiale di supporto

Note review suggerite:

Run with Bobby e' gratuita. Il coaching locale resta disponibile senza acquisti, senza StoreKit e senza paywall. I provider cloud sono opzionali e funzionano solo con API key gia' possedute dall'utente, salvate nel Keychain. L'app non usa login consumer Claude.ai o ChatGPT. Apple Health viene letto in sola lettura; quando un provider cloud e' selezionato, chat, profilo runner e riepiloghi Health necessari possono essere inviati al provider scelto per generare la risposta.

Privacy checklist:

- Nessun tracking pubblicitario o analytics di terze parti.
- Dati salvati localmente: conversazioni, profilo runner, piani allenamento e piani alimentari.
- Dati HealthKit: lettura on-demand e in sola lettura; non vengono persistiti dall'app.
- Segreti: API key utente nel Keychain; `.env` solo sviluppo locale.
- Prima della submission eseguire `scripts/scan-secrets.sh` e verificare `PRIVACY_AND_SECURITY.md`.
