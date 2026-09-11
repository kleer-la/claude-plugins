# Voices

The country is a parameter, not a code decision. `edge-tts` is free and needs
no API key; the engine passes `--voice` and that is it.

Kleer defaults to Argentine Spanish. Override per run with `VOICE=`.

## Picking one

```json
{ "defaults": { "voice": "es-AR-ElenaNeural" } }
```

`VOICE=es-AR-TomasNeural` in the environment renders the same briefing in the
other Argentine voice without editing anything.

## Rate

`RATE` adjusts the speed (`+8%` is the default). Slightly faster sounds less
robotic over a few minutes.

## Spanish voices worth knowing

Verified against `edge-tts --list-voices`:

```
es-AR-ElenaNeural
es-AR-TomasNeural
es-CO-SalomeNeural
es-MX-DaliaNeural
es-ES-ElviraNeural
es-US-PalomaNeural
```

Every Spanish-speaking country has a voice. For the full list:

```bash
edge-tts --list-voices
```

## Other languages

`en-US-JennyNeural`, `en-GB-SoniaNeural`, and so on. One briefing file per
language — see [briefing.md](briefing.md).

This catalogue is the same service e2e-video-doc uses. A voice that works
there works here.
