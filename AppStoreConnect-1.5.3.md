# App Store Connect 1.5.3

Campi da impostare in App Store Connect prima della submission:

- Versione: 1.5.3
- Build da reinviare: **8** (stesso binario già in review; non creare 1.5.4)
- Distribuzione: App Store (listing pubblica)
- Prezzo: Gratis
- Disponibilità: **China mainland deselezionato** (Hong Kong e Macao restano)
- Privacy Policy URL: https://bobby-lagotto.github.io/run-with-bobby/privacy.html (EN: https://bobby-lagotto.github.io/run-with-bobby/en/privacy.html)
- Support URL: https://github.com/bobby-lagotto/run-with-bobby/issues
- Repository (open source, GPL-3.0): https://github.com/bobby-lagotto/run-with-bobby

What's New (suggerito):

- Coach più preciso: salute, briefing di oggi, piani e aderenza arrivano dai dati e dai tool, non da numeri inventati.
- Su iPhone con modello locale, Bobby resta nel ruolo di coach e non risponde più con rifiuti su privacy/leggi.
- Salvataggi e ottimizzazioni del piano solo dopo conferma esplicita; niente apply nello stesso turno del calcolo.

## Resubmit dopo Guideline 5.0.0 Legal (Cina / OpenAI)

Apple ha respinto 1.5.3 (8) perché i metadata citano OpenAI e lo storefront **China mainland** era selezionato. Percorso scelto: **non distribuire in Cina continentale**. Nessun nuovo archive. Non cambiare nome, sottotitolo, descrizione, screenshot, keyword.

Da questo repository non si può cliccare Submit: i passi 1–5 si fanno in App Store Connect.

1. Sidebar **Prezzi e disponibilità** (livello app, non pagina versione) → App Availability / Paesi e regioni → deseleziona **China mainland**. Non togliere Hong Kong o Macao.
2. Conferma prezzo **Gratis** (0) su tutti i paesi restanti. Nessun IAP.
3. Versione **1.5.3** → **Note per la revisione**: incolla il blocco EN sotto, poi il resto delle note.
4. Thread **Messaggi** della submission `ec406992-4537-4119-869a-98cc584a1b8e`: incolla la risposta sotto.
5. **Invia di nuovo** la versione 1.5.3, build **8**.

Dopo il resubmit: stato “In attesa di verifica”; Availability senza China mainland; Review Notes con la conferma Cina.

### Note review (incolla in testa, in inglese)

```
China mainland storefront is deselected. Run with Bobby is not distributed in mainland China.

Optional OpenAI / Anthropic / OpenRouter remain available only outside China, and only if the user pastes their own API key. There is no ChatGPT or Claude.ai consumer login. Default coaching is on-device (MLX).

Run with Bobby is free. Local coaching stays available with no purchases, no StoreKit, and no paywall. Cloud providers are optional and only work with an API key the user already owns, stored in the Keychain. Apple Health is read to personalize recovery and briefing; the app writes a workout to Health only if the user records a run. When a cloud provider is selected, chat, runner profile, and the Health summaries needed to answer may be sent to that provider.
```

### Risposta al messaggio Apple (thread Messaggi)

```
Hello,

China mainland has been deselected in App Availability. Run with Bobby is not distributed in mainland China.

Optional OpenAI / Anthropic / OpenRouter stay available only outside China, and only if the user pastes their own API key. There is no ChatGPT consumer login. We are resubmitting the same build 1.5.3 (8).

Thank you.
```

Privacy checklist:

- Nessun tracking pubblicitario o analytics di terze parti.
- Dati salvati localmente: conversazioni, profilo runner, piani allenamento e piani alimentari.
- Dati HealthKit: lettura on-demand; scrittura workout solo se registri una seduta; i riepiloghi non vengono persistiti dall'app.
- Segreti: API key utente nel Keychain; `.env` solo sviluppo locale.
- Prima della submission eseguire `scripts/scan-secrets.sh` e verificare `PRIVACY_AND_SECURITY.md`.

Listing pubblica (screenshot, descrizione, keyword, build 8): vedi `AppStoreConnect-public.md`.
