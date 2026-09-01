---
name: Something did not work
about: A failed run, a wrong frame, a stack that does not fit
labels: bug
---

## What happened

<!-- What you asked for, and what you got instead. Exact error text if it is short. -->

## Where

- OS (and WSL distro if Windows):
- Stack (Rails/Capybara, Playwright, other):
- How the app runs (devcontainer, local server, remote):

## Tooling

```
for c in edge-tts ffmpeg ffprobe jq python3; do printf "%-10s %s\n" "$c" "$(command -v $c || echo MISSING)"; done
```

<!-- Paste the output. If the app runs in a container, run it there too — they differ more often than you would think. -->

## The frames

<!-- If a video came out wrong rather than failing: what did the PNGs in the screenshots
directory look like? A capture that passes and photographs the wrong thing is the most
common failure, and the only way to see it is to look. Attach one if you can. -->

## Diff

<!-- If you patched a recipe or the engine to get past it, paste the diff — nobody else
has hit your case, so whatever you changed is probably a real bug for everyone. -->
