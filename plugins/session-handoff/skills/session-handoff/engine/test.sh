#!/usr/bin/env bash
# Regression for the engine and the hooks. Needs no Claude Code session.
# Run from anywhere:
#   bash skills/session-handoff/engine/test.sh
#
# Exits 1 on the first failure. Speaks what it did.

set -euo pipefail

ENGINE_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$ENGINE_DIR/../../.." && pwd)"

echo "== check.sh"
bash "$ENGINE_DIR/check.sh"

echo "== make_brief.sh (fixture)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BRIEFING="$PLUGIN_DIR/examples/fixture-briefing.json" \
  OUTPUT="$TMP/fixture.mp3" \
  VOICE=es-AR-ElenaNeural \
  bash "$ENGINE_DIR/make_brief.sh"
[ -f "$TMP/fixture.mp3" ] || { echo "no mp3 written"; exit 1; }
SIZE=$(wc -c < "$TMP/fixture.mp3" | tr -d ' ')
[ "$SIZE" -gt 1000 ] || { echo "mp3 too small: $SIZE bytes"; exit 1; }
echo "   fixture mp3: $SIZE bytes"

echo "== make_brief.sh remote backend (stub server: payload, 401 stops, 5xx falls back)"
cat > "$TMP/stub.py" <<'PY'
import http.server, sys
status, seen, portfile = int(sys.argv[1]), sys.argv[2], sys.argv[3]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        open(seen, 'wb').write(self.headers.get('Authorization', '').encode() + b'\n' + raw)
        body = b'ID3' + b'x' * 2000 if status == 200 else b'{"error":"stub"}'
        self.send_response(status)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
srv = http.server.HTTPServer(('127.0.0.1', 0), H)
open(portfile, 'w').write(str(srv.server_port))
srv.handle_request()
PY
start_stub() {
  rm -f "$TMP/port" "$TMP/seen"
  python3 "$TMP/stub.py" "$1" "$TMP/seen" "$TMP/port" & STUB_PID=$!
  for _ in $(seq 50); do [ -s "$TMP/port" ] && break; sleep 0.1; done
  STUB_URL="http://127.0.0.1:$(cat "$TMP/port")/api/tts/briefing"
}
cat > "$TMP/remote-briefing.json" <<'JSON'
{"beats":[{"narration":"uno","duration":1000},{"narration":"","duration":5},{"narration":"dos"}]}
JSON

start_stub 200
SESSION_HANDOFF_TTS_TOKEN=tok SESSION_HANDOFF_TTS_URL="$STUB_URL" \
  BRIEFING="$TMP/remote-briefing.json" OUTPUT="$TMP/remote.mp3" bash "$ENGINE_DIR/make_brief.sh" >/dev/null
wait "$STUB_PID"
[ "$(wc -c < "$TMP/remote.mp3" | tr -d ' ')" -eq 2003 ] || { echo "remote mp3 not the stub's bytes"; exit 1; }
[ "$(head -1 "$TMP/seen" | tr -d '\r')" = "Bearer tok" ] || { echo "token not sent as a bearer"; exit 1; }
[ "$(tail -n +2 "$TMP/seen" | jq -c '[.beats[] | [.narration, .duration]]')" = '[["uno",60],["dos",0]]' ] \
  || { echo "payload wrong (empty beat kept, or duration not capped at 60)"; exit 1; }
[ ! -e "$TMP/remote.mp3.part" ] || { echo "leftover .part file"; exit 1; }
echo "   200: mp3 written, bearer sent, empty beat dropped, duration capped"

start_stub 401
set +e
SESSION_HANDOFF_TTS_TOKEN=bad SESSION_HANDOFF_TTS_URL="$STUB_URL" \
  BRIEFING="$TMP/remote-briefing.json" OUTPUT="$TMP/rejected.mp3" bash "$ENGINE_DIR/make_brief.sh" >/dev/null 2>&1
code=$?
set -e
wait "$STUB_PID"
[ "$code" -eq 1 ] && [ ! -e "$TMP/rejected.mp3" ] || { echo "401 should stop with no mp3 (exit $code)"; exit 1; }
echo "   401: stops, no fallback"

start_stub 504
SESSION_HANDOFF_TTS_TOKEN=tok SESSION_HANDOFF_TTS_URL="$STUB_URL" \
  BRIEFING="$PLUGIN_DIR/examples/fixture-briefing.json" OUTPUT="$TMP/fallback.mp3" \
  bash "$ENGINE_DIR/make_brief.sh" >/dev/null 2>&1
wait "$STUB_PID"
[ "$(wc -c < "$TMP/fallback.mp3" | tr -d ' ')" -gt 10000 ] || { echo "504 did not fall back to the local engine"; exit 1; }
echo "   504: fell back to the local engine"

echo "== hooks: session-start, post-tool, compact does not reset HEAD"
REPO="$TMP/proj"
mkdir -p "$REPO/docs"
git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name test
echo "one" > "$REPO/docs/canvas.md"
git -C "$REPO" add docs/canvas.md
git -C "$REPO" commit -q -m first
HEAD=$(git -C "$REPO" rev-parse HEAD)

printf '{"session_id":"s1","cwd":"%s","source":"startup"}\n' "$REPO" \
  | bash "$PLUGIN_DIR/hooks/session-start.sh"
[ -f "$REPO/.claude/session-handoff/start.json" ] || { echo "start.json missing"; exit 1; }
GOT=$(jq -r '.git.head' "$REPO/.claude/session-handoff/start.json")
[ "$GOT" = "$HEAD" ] || { echo "HEAD mismatch: $GOT vs $HEAD"; exit 1; }

echo "two" >> "$REPO/docs/canvas.md"
printf '{"cwd":"%s","tool_input":{"file_path":"%s/docs/canvas.md"}}\n' "$REPO" "$REPO" \
  | bash "$PLUGIN_DIR/hooks/post-tool.sh"
grep -qx 'docs/canvas.md' "$REPO/.claude/session-handoff/touched.txt"

# compact must not take the new (dirty) tree as the baseline
printf '{"session_id":"s1","cwd":"%s","source":"compact"}\n' "$REPO" \
  | bash "$PLUGIN_DIR/hooks/session-start.sh"
GOT=$(jq -r '.git.head' "$REPO/.claude/session-handoff/start.json")
[ "$GOT" = "$HEAD" ] || { echo "compact reset HEAD to $GOT"; exit 1; }

echo "== diff.sh sees the change"
bash "$ENGINE_DIR/diff.sh" "$REPO" >/dev/null
grep -q 'docs/canvas.md' "$REPO/.claude/session-handoff/files.txt"
grep -q '+two' "$REPO/.claude/session-handoff/changes.diff"

echo "== diff.sh exit 2 when nothing changed"
REPO2="$TMP/clean"
mkdir -p "$REPO2"
git -C "$REPO2" init -q
git -C "$REPO2" config user.email test@example.com
git -C "$REPO2" config user.name test
echo "x" > "$REPO2/a.md"
git -C "$REPO2" add a.md
git -C "$REPO2" commit -q -m first
printf '{"session_id":"s2","cwd":"%s","source":"startup"}\n' "$REPO2" \
  | bash "$PLUGIN_DIR/hooks/session-start.sh"
set +e
bash "$ENGINE_DIR/diff.sh" "$REPO2" >/dev/null
code=$?
set -e
[ "$code" -eq 2 ] || { echo "expected exit 2, got $code"; exit 1; }

echo "== session-end copies a transcript"
printf '{"cwd":"%s","transcript_path":"%s"}\n' "$REPO" "$REPO/docs/canvas.md" \
  | bash "$PLUGIN_DIR/hooks/session-end.sh"
[ -f "$REPO/.claude/session-handoff/transcript.jsonl" ] || { echo "transcript not copied"; exit 1; }

echo "All engine and hook checks passed."
exit 0
