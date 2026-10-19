#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

test_root=$(mktemp -d /tmp/NotesSmoke.XXXXXX)
cp -R dist/Notes.app "$test_root/Notes.app"
cleanup() {
    if [[ -n "${app_pid:-}" ]]; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -rf "$test_root"
}
trap cleanup EXIT

NOTES_DATA_FILE="$test_root/notes.json" "$test_root/Notes.app/Contents/MacOS/Notes" \
    >"$test_root/stdout.log" 2>"$test_root/stderr.log" &
app_pid=$!
for _ in {1..20}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        cat "$test_root/stderr.log" >&2
        echo "Notes exited during GUI smoke test" >&2
        exit 1
    fi
    if [[ -s "$test_root/notes.json" ]]; then break; fi
    sleep 1
done

python3 - "$test_root/notes.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
assert isinstance(data, dict) and isinstance(data.get('notes'), list)
PY
sleep 3
kill -0 "$app_pid"
echo "Relocated app launch and isolated note storage verified"
