# The briefing JSON

An object. `beats` is the array the engine reads. Everything else is for the
human who reviews it before TTS.

```json
{
  "title": "Canvas de precios — sesión de Juan, 11 sep",
  "audience": "el equipo del producto compartido",
  "duration_target": 180,
  "outcome": "Sacamos el tier Enterprise y dejamos abierta la pregunta del descuento anual.",
  "artifact": { "kind": "git", "path": "docs/pricing.md", "ref": "main" },
  "beats": [
    {
      "kind": "open",
      "duration": 6,
      "narration": "Hoy con el agente actualicé el canvas de precios."
    },
    {
      "kind": "decision",
      "duration": 8,
      "rejected": "dejarlo como contact us",
      "narration": "Sacamos Enterprise. Nadie lo pide y ensucia la tabla."
    },
    {
      "kind": "change",
      "duration": 8,
      "path": "docs/pricing.md",
      "narration": "En la tabla quedaron Solo y Team. Team pasa a cuarenta y nueve."
    },
    {
      "kind": "open-question",
      "duration": 6,
      "narration": "Sigue abierta la pregunta del descuento anual. La dejo para ustedes."
    },
    {
      "kind": "where",
      "duration": 5,
      "narration": "El diff está en docs slash pricing punto md, en el commit de esta tarde."
    }
  ]
}
```

## What the engine uses

| Field | Required | What it is |
|---|---|---|
| `beats` | yes | Non-empty array, in listening order. |
| `beats[].narration` | yes | The text that gets synthesised. Empty beats are skipped. |
| `beats[].duration` | no | A **floor** in seconds, not an exact value. Default 0. |

A segment lasts `max(audio duration + 0.35, duration)`. If the narration runs
long, the beat follows — the voice is never cut off mid-sentence. Set
`duration` only when you want a pause longer than it takes to read.

## What the engine ignores (and the reviewer does not)

| Field | What it is |
|---|---|
| `title` | Names the session. Used for the filename slug, not spoken unless you put it in a beat. |
| `audience` | Who this is for. Write the narration *to* them. |
| `outcome` | One sentence. If you cannot write it, the session is not ready to brief. |
| `artifact` | The shared document. `kind` is `git` in v1. |
| `beats[].kind` | `open` · `decision` · `change` · `open-question` · `where`. Orders the story; the engine does not care. |
| `beats[].path` | For `change` beats: a path that appears in `files.txt`. |
| `beats[].rejected` | The alternative that was considered and dropped. Gold for teammates; not spoken unless the narration says it. |

## Writing the narration

- Speak to the people who were not there. "Sacamos Enterprise", not "then I
  asked the agent to delete a heading".
- Say what was decided and what was discarded. The discarded part is what the
  diff will never show.
- Short sentences. Synthetic voices stumble over long subordinate clauses.
- Numbers and acronyms: spell them how they should be read if the voice gets
  them wrong. "cuarenta y nueve", "docs slash pricing punto md".
- Three to four minutes. Longer than that, the team will not finish it.
- First person is the person who did the work, not the agent.

## One language per file

`briefing.json`, `briefing_en.json`, and so on. Same beats, same `path` keys,
different `narration` and `VOICE=`. Regenerating in another voice is a script
and no model.

## The file on disk

Write it to `.claude/session-handoff/briefing.json` so it sits with
`start.json` and `changes.diff`. The MP3 does **not** go there — see
[gotchas](gotchas.md), "the audio cannot live in tmp/".
