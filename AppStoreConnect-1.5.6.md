# App Store Connect 1.5.6

Campi da impostare in App Store Connect prima della submission:

- Versione: 1.5.6
- Build da inviare: **14**
- Distribuzione: App Store (listing pubblica)
- Prezzo: Gratis
- Disponibilità: **China mainland deselezionato** (Hong Kong e Macao restano)
- Privacy Policy URL: https://bobby-lagotto.github.io/run-with-bobby/privacy.html (EN: https://bobby-lagotto.github.io/run-with-bobby/en/privacy.html)
- Support URL: https://github.com/bobby-lagotto/run-with-bobby/issues
- Repository (open source, GPL-3.0): https://github.com/bobby-lagotto/run-with-bobby

What's New (suggerito):

- First chat builds a weekly plan from the onboarding profile. No model download and no API key required.
- “New plan” always generates a draft; “Save plan” (or yes / save) activates it.
- Chat layout verified on iPad in iPhone compatibility mode (Guideline 2.1).

## Submit dopo Guideline 2.1 App Completeness (piano in chat)

Apple ha respinto **1.5.3 (12)** su iPad Air 11-inch: il coach ripeteva la stessa domanda e non creava un piano (né si poteva bypassare la chat) quando non c’erano modello locale né API key. Nuova versione **1.5.6 (14)**.

Da questo repository non si può cliccare Submit: i passi si fanno in App Store Connect.

1. Archivia e carica la build **14** (versione 1.5.6).
2. Crea/seleziona la versione **1.5.6** e collega la build **14**.
3. Conferma **China mainland** deselezionato (Guideline 5 precedente).
4. **Note per la revisione**: incolla il blocco EN sotto.
5. Thread **Messaggi** della submission `ec406992-4537-4119-869a-98cc584a1b8e`: incolla la risposta 2.1 sotto.
6. Invia.

### Note review (incolla in testa, in inglese)

```
Guideline 2.1: a training plan is created from the onboarding profile on first chat, with no model download and no API key.

Path: finish onboarding (defaults OK) → chat shows a generated weekly plan → tap Save plan. “New plan” regenerates a draft from the profile.

Demo account: not required. Do not download a local model. Do not paste an API key.

China mainland remains deselected. HealthKit is optional (Later). Sources (ISSN/ACSM) stay in onboarding, Settings, and chat … menu.
```

### Risposta al messaggio Apple (thread Messaggi) — Guideline 2.1

```
Hello,

Thank you for the Guideline 2.1 feedback on 1.5.3 (12), reviewed on iPad Air 11-inch.

The chat could not create a plan when no on-device model and no cloud API key were configured (typical first launch). The coach asked “Want me to make a plan from your profile?” and never built it, so the same question repeated after “create a new plan”.

This is fixed in 1.5.6 (14). No API key and no model download are required to get a plan:

1. Complete onboarding (defaults are fine; language Italian or English).
2. Chat opens with an example request that builds a weekly plan from the onboarding profile.
3. Tap “New plan” at any time to generate another draft.
4. Tap “Save plan” (or type yes / save) to activate it. Today and Plan archive then show that plan.

The app is iPhone-only; we also verified the chat layout and those actions on iPad in compatibility mode.

China mainland remains deselected. Optional OpenAI / Anthropic / OpenRouter still require the user’s own API key.

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
