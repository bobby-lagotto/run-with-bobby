# App Store Connect 1.5.4

Campi da impostare in App Store Connect prima della submission:

- Versione: 1.5.4
- Build da inviare: **10**
- Distribuzione: App Store (listing pubblica)
- Prezzo: Gratis
- Disponibilità: **China mainland deselezionato** (Hong Kong e Macao restano)
- Privacy Policy URL: https://bobby-lagotto.github.io/run-with-bobby/privacy.html (EN: https://bobby-lagotto.github.io/run-with-bobby/en/privacy.html)
- Support URL: https://github.com/bobby-lagotto/run-with-bobby/issues
- Repository (open source, GPL-3.0): https://github.com/bobby-lagotto/run-with-bobby

What's New (suggerito):

- Fonti ISSN e ACSM per nutrizione e recupero, con link DOI in onboarding, Impostazioni e menu chat.
- Onboarding: scelta esplicita di italiano o inglese; Bobby risponde in quella lingua.
- Footer “non è consiglio medico” sulle indicazioni salute/dieta (Guideline 1.4.1).

## Submit dopo Guideline 1.4.1 Physical Harm (citazioni)

Apple ha respinto 1.5.3 (9) perché le indicazioni su dieta/salute nel binario non avevano citazioni con link. Nuova versione **1.5.4 (10)**.

Da questo repository non si può cliccare Submit: i passi si fanno in App Store Connect.

1. Archivia e carica la build **10** (versione 1.5.4).
2. Crea/seleziona la versione **1.5.4** e collega la build **10**.
3. Conferma **China mainland** deselezionato (Guideline 5 precedente).
4. **Note per la revisione**: incolla il blocco EN sotto.
5. Thread **Messaggi** della submission `ec406992-4537-4119-869a-98cc584a1b8e`: incolla la risposta 1.4.1 sotto.
6. Invia.

### Note review (incolla in testa, in inglese)

```
Guideline 1.4.1: health and diet notes now cite ISSN and ACSM with tappable DOI links.

Sources are easy to find: onboarding (right after language), Settings > Sources and safety (top of Settings, not behind Advanced), and the chat … menu > Sources.

Nutrition and recovery replies include a footer: “This is not medical advice. Sources: ISSN and ACSM.” Bobby is a running coach, not a clinician.

Onboarding asks the user to choose Italian or English. The coach UI and on-device replies follow that language.

China mainland storefront remains deselected. Optional OpenAI / Anthropic / OpenRouter stay available only outside China, and only if the user pastes their own API key.
```

### Risposta al messaggio Apple (thread Messaggi) — Guideline 1.4.1

```
Hello,

Thank you for the 1.4.1 feedback. We added citations for the health and diet information in the app.

Sources (ISSN Position Stand on protein and exercise; ACSM/AND/DC Nutrition and Athletic Performance; ISSN nutrient timing; ACSM Exercise and Fluid Replacement) are linked by DOI and are easy to find:

1. Onboarding, immediately after the user chooses Italian or English
2. Settings > Sources and safety (at the top of Settings)
3. Chat menu > Sources

Nutrition, recovery and health replies now include a short footer that this is not medical advice and that the sources are ISSN and ACSM.

Onboarding now asks for Italian or English so the coach answers in the selected language (this was the mismatch on the iPad review screenshot).

We are submitting a new binary, version 1.5.4 (10). China mainland remains deselected.

Thank you.
```

## China mainland (Guideline 5)

Resta deselezionato. Hong Kong e Macao restano. Prezzo Gratis. Nessun IAP.

Privacy checklist:

- Nessun tracking pubblicitario o analytics di terze parti.
- Dati salvati localmente: conversazioni, profilo runner, piani allenamento e piani alimentari.
- Dati HealthKit: lettura on-demand; scrittura workout solo se registri una seduta; i riepiloghi non vengono persistiti dall'app.
- Segreti: API key utente nel Keychain; `.env` solo sviluppo locale.
- Prima della submission eseguire `scripts/scan-secrets.sh` e verificare `PRIVACY_AND_SECURITY.md`.

Listing pubblica (screenshot, descrizione, keyword): vedi `AppStoreConnect-public.md`.
