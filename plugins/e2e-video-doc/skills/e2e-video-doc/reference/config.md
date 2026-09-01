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
      "capture": "docker exec -w /app \"$(bash \"$E2E_VIDEO_DOC_ENGINE/devcontainer.sh\" web)\" bin/rails test test/system/{flow}_video_test.rb"
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

## Several languages

Optional. Declare `languages` and the flow can be rendered in each one:

```json
{
  "defaults": {
    "screenshots": "tmp/video_screenshots/{flow}_{lang}",
    "narration": "scripts/{flow}_video_narration{lang_suffix}.json",
    "output": "public/videos/{flow}_{lang}.mp4",
    "capture": "docker exec -e VIDEO_LOCALE={lang} \"$(bash \"$E2E_VIDEO_DOC_ENGINE/devcontainer.sh\" web)\" bin/rails test test/system/{flow}_video_test.rb"
  },
  "languages": {
    "es": { "voice": "es-CO-SalomeNeural", "suffix": "" },
    "en": { "voice": "en-US-JennyNeural", "suffix": "_en" }
  }
}
```

```bash
bash run.sh checkout        # the first language declared
bash run.sh checkout en
```

`{lang}` is the code, `{lang_suffix}` is what the narration files append (often empty for
the primary language). Without a `languages` block both resolve to empty and everything
behaves as a single-language project.

**The capture step re-runs per language.** That is deliberate — see
[gotchas.md](gotchas.md), "the interface has to speak the same language as the voice".
The declaration order matters: the first language listed is the default.

| Key | What it is |
|---|---|
| `capture` | The command that runs the walkthrough and leaves the PNGs. **Yours**: your stack, your devcontainer, your fixtures. Runs from the repo root, with the variables below exported. |
| `screenshots` | Where it leaves them, relative to the repo root. |
| `narration` | The narration JSON for that flow. See [narration.md](narration.md). |
| `output` | Where the MP4 goes. **Outside `tmp/`** — see [gotchas.md](gotchas.md). |
| `voice` | See [voices.md](voices.md). A language's voice wins over the flow's, which wins over the default. `VOICE=` in the environment overrides all of them. |

## What `capture` gets from the runner

Both `run.sh` and the Windows path export these before running your command:

| Variable | What for |
|---|---|
| `RUN_VIDEO_TESTS=1` | The flag video specs sit behind so a normal test run skips them. |
| `E2E_VIDEO_DOC_ENGINE` | Absolute path to the plugin's `engine/`, so `capture` can call its helpers. |
| `SCREENSHOTS` | The resolved screenshots directory, for a capture step that has to add a frame of its own. |

`SCREENSHOTS` matters when something besides the browser contributes a frame — a title
card, a rasterised PDF. Those have to be written **after** the walkthrough, which usually
starts by emptying the directory:

```json
"capture": "docker exec ... bin/rails test test/system/{flow}_video_test.rb && LANG_CODE={lang} bash scripts/title_cards.sh \"$SCREENSHOTS\""
```

These examples interpolate inline with `$VAR`, which is bash: on Windows the capture
command goes through `cmd /c`, where the variables arrive but `$VAR` does not expand —
see [gotchas.md](gotchas.md). A capture step that has to run on both writes a small
script and reads the environment from inside it.

The one you will actually use is `devcontainer.sh`, which finds the container by the
repo it serves instead of by a name that changes underneath you — see
[gotchas.md](gotchas.md), "the container name is not stable". Note that `docker exec`
does not forward the host environment: pass what the test needs with `-e`.

## Why the plugin does not ship the capture step

Because it uses your factories, your login helper and your seeded data — and it has to age
with the project. **That is the feature**: when the screen changes and the walkthrough
breaks, the video fails the way an E2E test fails, which is why the documentation cannot
go stale in silence.

The plugin brings the engine, the contract and the recipes. The walkthrough is written per
project, in the stack it already has.
