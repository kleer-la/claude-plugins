# `e2e-video-doc.json`

The only thing you write per project. Lives at the repo root, committed.

```json
{
  "defaults": {
    "voice": "en-US-JennyNeural",
    "screenshots": "tmp/video_screenshots/{flow}",
    "narration": "scripts/{flow}_video_narration.json",
    "output": "public/videos/{flow}.mp4"
  },
  "flows": {
    "checkout": {
      "capture": "docker exec my_devcontainer-app-1 bin/rails test test/system/{flow}_video_test.rb"
    },
    "onboarding": {
      "capture": "npx playwright test tests/{flow}.video.spec.ts",
      "voice": "es-CO-SalomeNeural"
    }
  }
}
```

`{flow}` is replaced with the flow name. Each flow overrides whatever it needs from
`defaults`; usually it only defines `capture`.

| Key | What it is |
|---|---|
| `capture` | The command that runs the walkthrough and leaves the PNGs. **Yours**: your stack, your devcontainer, your fixtures. Runs from the repo root. |
| `screenshots` | Where it leaves them, relative to the repo root. |
| `narration` | The narration JSON for that flow. See [narration.md](narration.md). |
| `output` | Where the MP4 goes. **Outside `tmp/`** — see [gotchas.md](gotchas.md). |
| `voice` | See [voices.md](voices.md). `VOICE=` in the environment overrides it. |

## Why the plugin does not ship the capture step

Because it uses your factories, your login helper and your seeded data — and it has to age
with the project. **That is the feature**: when the screen changes and the walkthrough
breaks, the video fails the way an E2E test fails, which is why the documentation cannot
go stale in silence.

The plugin brings the engine, the contract and the recipes. The walkthrough is written per
project, in the stack it already has.
