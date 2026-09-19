# Git recipe

v1's only source of ground truth. The engine never sees git; this recipe
produces the diff the skill reads.

## What it promises

- **Before** is `git rev-parse HEAD` at SessionStart, stored in
  `.claude/session-handoff/start.json`. Compact and resume do not move it.
- **After** is the working tree when `engine/diff.sh` runs: committed,
  unstaged, and untracked (new files the session `Write`s).
- **Scope** is `paths` in `session-handoff.json`, or the files in
  `touched.txt` if `paths` is empty.

## What it writes

Under `.claude/session-handoff/`:

| File | Contents |
|---|---|
| `changes.diff` | Unified diff plus inlined new text files |
| `changes.stat` | `git diff --stat` plus `new file:` lines |
| `files.txt` | Unique paths, one per line |

Exit 0 if anything moved, 2 if not, 1 if git or `start.json` is missing. On 1 or 2
the skill offers review mode (decisions only) instead of a diff briefing.

## What it does not do

- It does not invent a before for a session that started without the plugin.
- It does not read Google Docs, Notion, or a wiki. Those need their own
  recipe and the same three files as the contract.
- It does not commit, push, or open a PR. The briefing points at the diff;
  shipping the change is still yours.
- It does not redact secrets inside the diff. The skill must not copy a
  leaked token from `changes.diff` into a beat.

## Checking it without Claude

```bash
bash skills/session-handoff/engine/test.sh
```

The hook and `diff.sh` cases in that script are this recipe.
