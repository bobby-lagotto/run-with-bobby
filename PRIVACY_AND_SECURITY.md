# Privacy and Security Data Map

This document tracks sensitive data handled by Run with Bobby and the controls expected before release.

## Data Categories

| Category | Examples | Storage | Network Flow | Controls |
| --- | --- | --- | --- | --- |
| API keys | OpenAI, Anthropic, OpenRouter keys | iOS Keychain | Sent only as provider authorization headers | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; never store in `UserDefaults`; never commit `.env` |
| Runner profile | Weekly kilometers, workouts, goal, pace, race distance, weight | Protected JSON in app Documents | Included in LLM context when a cloud provider is active | Complete file protection; excluded from backup; disclose cloud flow |
| Conversations | User and Bobby messages, timestamps | Protected JSON in app Documents | Last messages are sent to the selected cloud provider when cloud is active | Complete file protection; excluded from backup; user can delete conversations |
| Training plans | Weekly workouts, distances, descriptions, active plan | Protected JSON in app Documents | Can be included in chat context or prompt text | Complete file protection; excluded from backup |
| Nutrition plans | Macro targets, food examples, linked plan | Protected JSON in app Documents | Can be included in chat context when relevant | Complete file protection; excluded from backup |
| Health summaries | Heart rate, HRV, steps, sleep, workouts, VO2 Max, SpO2 | Not persisted by the app; fetched from HealthKit on demand | Tool result can be sent to the selected cloud provider when cloud is active | HealthKit permission; in-app disclosure; local mode avoids cloud transmission |
| Model files | Downloaded MLX model cache | App Documents/Models | Downloaded from model sources | Not user data; excluded from backup |
| Logs | Debug status only | Console during development | None | Redacted debug logs; no provider body or Health payload logging |

## Cloud Provider Rules

- `Local` mode must not fall back to cloud providers.
- `Auto` mode uses the local model when available; otherwise it may use a configured cloud provider.
- When OpenAI, Anthropic, or OpenRouter is active, prompts can include chat history, runner profile, active plan context, and Health summaries needed to answer the request.
- Provider API keys are user-provided and stored in Keychain.

## Secret Hygiene

- `.env` and `.env.local` are ignored and must never be committed.
- `.env.example` documents variable names without values.
- Run `scripts/scan-secrets.sh` before release or as a CI/pre-commit step.
- If a real secret is ever committed, rotate it before continuing.

## Release Checklist

- Confirm `scripts/scan-secrets.sh` passes.
- Confirm App Store privacy labels match the current data flows.
- Confirm the privacy policy explains local storage, optional cloud providers, and HealthKit access.
- Confirm user-facing copy does not promise that all data always stays on-device when cloud providers are enabled.
