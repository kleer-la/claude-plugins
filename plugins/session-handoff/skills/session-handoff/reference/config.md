# session-handoff.json

One file at the repo root. Optional: without it the skill uses the defaults
below and asks once for audience and voice.

```json
{
  "defaults": {
    "voice": "es-AR-ElenaNeural",
    "rate": "+8%",
    "output_dir": "handoffs",
    "audience": "the rest of the team"
  },
  "paths": ["docs/", "README.md"],
  "share": "ask"
}
```

| Field | Default | What it is |
|---|---|---|
| `defaults.voice` | `es-AR-ElenaNeural` | Passed to the engine as `VOICE=`. Override per run with the environment. |
| `defaults.rate` | `+8%` | Slightly faster sounds less robotic over a few minutes. |
| `defaults.output_dir` | `handoffs` | Where the MP3 lands, relative to the repo root. Create it. Do not use `tmp/`. |
| `defaults.audience` | `the rest of the team` | Written into `briefing.json` so the narration has someone to speak to. |
| `paths` | all touched files | Path prefixes that count as the shared artifact. Empty means "whatever the session touched, except the plugin's own state". A canvas that lives in `docs/` should say so, or a README edit becomes a briefing. |
| `share` | `ask` | `ask` — confirm before TTS, every time. `always` — they opted in for this repo; still strip secrets. |

`VOICE=` and `RATE=` in the environment override the config, so you can render
the same briefing in another accent without editing anything.

There is nothing else to configure. The engine does not read this file; the
skill does, and then calls `make_brief.sh` with the environment filled in.

## Remote synthesis (no `edge-tts`, no `ffmpeg`)

Set these in the environment of the session, not in `session-handoff.json` — the token is a secret.

| Variable | Default | What it is |
|---|---|---|
| `SESSION_HANDOFF_TTS_TOKEN` | unset | Your personal token. When set, `make_brief.sh` sends the beats to the synthesis service and gets one finished MP3 back. Needs only `curl` and `jq`. |
| `SESSION_HANDOFF_TTS_URL` | the Kleer service | Override the service address. |

- **Remote first, local second.** No token → the local engine, exactly as before.
- **A 429 (over its limits), 503 (busy or switched off), 5xx or an unreachable service** falls back to the local engine, and the message shows the service's `Retry-After`. The plugin never retries the service itself. **A 401/403 or any other 4xx stops** with the service's message: falling back would hide a wrong token.
- **The narration leaves your machine**: it goes to the service, which sends it to Microsoft's speech service. The skill already strips secrets before writing the briefing; that is what protects you here.
- The service limits a briefing to 40 beats and 6000 characters of narration, and caps each beat's `duration` at 60 s. Keep it short.
