#!/usr/bin/env bash
# One command launcher: checks requirements, starts the server, opens the app.
#
#   ./run.sh            start and open the browser
#   PORT=9000 ./run.sh  prefer another port
#   NO_BROWSER=1 ./run.sh   start the server only
#
# Requirements: Python 3.8 or newer (standard library only) and a Chromium based
# browser (Chrome, Brave, Edge, Chromium or Arc), because Web MIDI with SysEx is
# not available in Safari or Firefox.

set -u
cd "$(dirname "$0")"

say()  { printf '%s\n' "$*"; }
fail() { printf 'Cannot start: %s\n' "$*" >&2; exit 1; }

# ---- Python -----------------------------------------------------------------
command -v python3 >/dev/null 2>&1 || {
  if [ "$(uname)" = "Darwin" ]; then
    fail "python3 is missing. Run: xcode-select --install   (or: brew install python), then ./run.sh again."
  fi
  fail "python3 is missing. Install Python 3.8 or newer with your package manager."
}
# On a Mac without developer tools, python3 is a stub that opens an install dialog.
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1 || {
  if [ "$(uname)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
    fail "Python is not installed yet. Finish the developer tools install dialog (or run: brew install python), then ./run.sh again."
  fi
  fail "Python 3.8 or newer is required. Found: $(python3 --version 2>&1)."
}

[ -f app/index.html ] || fail "app/index.html not found next to run.sh."
[ -f serve.py ]       || fail "serve.py not found next to run.sh."
mkdir -p banks

# ---- Port -------------------------------------------------------------------
port_free() {
  python3 -I - "$1" <<'EOF'
import socket, sys
s = socket.socket()
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
EOF
}
is_gyra() { curl -fs --max-time 1 "http://127.0.0.1:$1/api/banks" >/dev/null 2>&1; }

PORT="${PORT:-8765}"
URL=""
for p in $(seq "$PORT" $((PORT + 10))); do
  if is_gyra "$p"; then
    URL="http://127.0.0.1:$p"
    say "Gyra is already running at $URL"
    SERVER_RUNNING=1
    break
  fi
  if port_free "$p"; then
    PORT="$p"; SERVER_RUNNING=0; break
  fi
done
[ -n "$URL" ] || [ "${SERVER_RUNNING:-}" = "0" ] || fail "no free port between $PORT and $((PORT + 10))."

# ---- Browser ----------------------------------------------------------------
open_url() {
  local url="$1"
  [ "${NO_BROWSER:-}" = "1" ] && return 0
  if [ "$(uname)" = "Darwin" ]; then
    local app
    for app in "Google Chrome" "Brave Browser" "Microsoft Edge" "Chromium" "Arc"; do
      if [ -d "/Applications/$app.app" ] || [ -d "$HOME/Applications/$app.app" ]; then
        open -a "$app" "$url" && return 0
      fi
    done
    say "No Chrome, Brave, Edge, Chromium or Arc found. Web MIDI needs one of them."
    say "Install one, then open $url"
    return 0
  fi
  local bin
  for bin in google-chrome google-chrome-stable chromium chromium-browser brave-browser microsoft-edge; do
    if command -v "$bin" >/dev/null 2>&1; then "$bin" "$url" >/dev/null 2>&1 & return 0; fi
  done
  say "No Chromium based browser found. Web MIDI needs one. Open $url"
}

if [ "${SERVER_RUNNING:-0}" = "1" ]; then
  open_url "$URL"
  exit 0
fi

# ---- Start ------------------------------------------------------------------
URL="http://127.0.0.1:$PORT"
python3 -I serve.py "$PORT" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null' EXIT INT TERM

for _ in $(seq 1 50); do
  kill -0 "$SERVER_PID" 2>/dev/null || fail "the server stopped right after starting."
  is_gyra "$PORT" && break
  sleep 0.1
done
is_gyra "$PORT" || fail "the server did not answer on port $PORT."

say "Gyra at $URL"
say "Banks are saved in $(pwd)/banks. Press Ctrl+C to stop."
open_url "$URL"
wait "$SERVER_PID"
