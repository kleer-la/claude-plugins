# The narration JSON

An array, one object per screen, in video order.

```json
[
  {
    "screenshot": "01_login.png",
    "duration": 6,
    "narration": "The user signs in with the credentials they got by email."
  },
  {
    "screenshot": "02_order.png",
    "duration": 8,
    "narration": "They build the order. The total updates as they add items."
  }
]
```

| Field | What it is |
|---|---|
| `screenshot` | File name inside the screenshots directory. |
| `duration` | A **floor** in seconds, not an exact value. |
| `narration` | The text that gets synthesised. |

## `duration` is a floor

A segment lasts `max(audio duration + 0.5, duration)`. If the narration runs long, the
image follows — the voice is never cut off mid-sentence. Set `duration` only when you want
a screen to linger longer than it takes to read.

## The file name orders the video

`NN_name.png`, two digits starting at 01. The capture helper assigns the number by
incrementing; you only pass the name.

The JSON order wins over the disk order, but keeping them aligned is what makes a diff of
the JSON readable.

## When a screenshot is missing

The engine skips it, says so, and reports how many were missing at the end. If **all** of
them are missing it stops with a clear message rather than letting ffmpeg emit its own.

## One language per file

`checkout_video_narration.json`, `checkout_video_narration_es.json`, and so on. Same
`screenshot` keys, same number of entries, different `narration` and `voice`.

Adding or removing a screen means touching **every** language file. This is where these
drift out of sync most often.

## Writing the narration

- Say what the user is achieving, not what the screen displays. "They build the order",
  not "the order form is shown".
- Short sentences. Synthetic voices stumble over long subordinate clauses.
- Numbers and acronyms: spell them how they should be read if the voice gets them wrong.
- Three to four minutes is the length that works. Longer than that, split it into two
  flows.
