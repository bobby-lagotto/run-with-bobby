# App Store Connect 1.5.3

Campi da impostare in App Store Connect prima della submission:

- Versione: 1.5.3
- Build: 6 (listing pubblica; la 5 resta in TestFlight)
- Distribuzione iniziale: TestFlight, poi App Store
- Prezzo: Gratis
- Privacy Policy URL: https://github.com/bobby-lagotto/run-with-bobby/blob/master/PRIVACY_AND_SECURITY.md
- Support URL: https://github.com/bobby-lagotto/run-with-bobby/issues
- Repository (open source, GPL-3.0): https://github.com/bobby-lagotto/run-with-bobby

What's New (suggerito):

- Coach più preciso: salute, briefing di oggi, piani e aderenza arrivano dai dati e dai tool, non da numeri inventati.
- Su iPhone con modello locale, Bobby resta nel ruolo di coach e non risponde più con rifiuti su privacy/leggi.
- Salvataggi e ottimizzazioni del piano solo dopo conferma esplicita; niente apply nello stesso turno del calcolo.

Note review suggerite:

Run with Bobby e' gratuita. Il coaching locale resta disponibile senza acquisti, senza StoreKit e senza paywall. I provider cloud sono opzionali e funzionano solo con API key gia' possedute dall'utente, salvate nel Keychain. L'app non usa login consumer Claude.ai o ChatGPT. Apple Health viene letto per personalizzare recupero e briefing; l'app scrive un workout in Salute solo se l'utente registra una seduta di corsa. Quando un provider cloud e' selezionato, chat, profilo runner e riepiloghi Health necessari possono essere inviati al provider scelto per generare la risposta.

Privacy checklist:

- Nessun tracking pubblicitario o analytics di terze parti.
- Dati salvati localmente: conversazioni, profilo runner, piani allenamento e piani alimentari.
- Dati HealthKit: lettura on-demand; scrittura workout solo se registri una seduta; i riepiloghi non vengono persistiti dall'app.
- Segreti: API key utente nel Keychain; `.env` solo sviluppo locale.
- Prima della submission eseguire `scripts/scan-secrets.sh` e verificare `PRIVACY_AND_SECURITY.md`.

Listing pubblica (screenshot, descrizione, keyword, build 6): vedi `AppStoreConnect-public.md`.
