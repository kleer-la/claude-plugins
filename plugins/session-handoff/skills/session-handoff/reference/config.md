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
