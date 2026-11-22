#!/usr/bin/env python3
"""Serves the app and stores banks as .bcr files in the banks folder.

    python3 serve.py [port]

Open http://127.0.0.1:8765 (Chrome, Edge or Brave, for Web MIDI).
The server listens on 127.0.0.1 only. Writes need the X-Gyra header, which a
web page from another origin cannot send without a CORS preflight that this
server never approves.
"""
import http.server
import json
import os
import re
import sys
import tempfile
import urllib.parse

ROOT = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(ROOT, "app")
BANKS = os.path.join(ROOT, "banks")
NAME = re.compile(r"^[^/\\:*?\"<>|\x00-\x1f.][^/\\:*?\"<>|\x00-\x1f]*\.bcr$")
MAX_BYTES = 2_000_000


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=APP, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        if "/api/" in (self.path or "") and self.command != "GET":
            sys.stderr.write("%s %s\n" % (self.command, urllib.parse.unquote(self.path)))

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _bank_path(self):
        parts = urllib.parse.urlsplit(self.path).path.split("/")
        if len(parts) != 4:
            return None
        name = urllib.parse.unquote(parts[3])
        if not NAME.match(name) or name != os.path.basename(name):
            return None
        return os.path.join(BANKS, name)

    def _host_ok(self):
        host = (self.headers.get("Host") or "").split(":")[0]
        return host in ("127.0.0.1", "localhost")

    def do_GET(self):
        if not self._host_ok():
            return self._json(403, {"error": "bad host"})
        path = urllib.parse.urlsplit(self.path).path
        if path == "/api/banks":
            os.makedirs(BANKS, exist_ok=True)
            out = []
            for f in sorted(os.listdir(BANKS)):
                p = os.path.join(BANKS, f)
                if NAME.match(f) and os.path.isfile(p):
                    with open(p, encoding="utf-8", errors="replace") as fh:
                        out.append({"file": f, "mtime": os.path.getmtime(p), "text": fh.read()})
            return self._json(200, out)
        return super().do_GET()

    def do_PUT(self):
        if not self._host_ok() or "X-Gyra" not in self.headers:
            return self._json(403, {"error": "forbidden"})
        p = self._bank_path()
        if not p:
            return self._json(400, {"error": "bad bank name"})
        n = int(self.headers.get("Content-Length") or 0)
        if n > MAX_BYTES:
            return self._json(413, {"error": "too large"})
        data = self.rfile.read(n)
        os.makedirs(BANKS, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=BANKS, prefix=".tmp-")
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, p)
        return self._json(200, {"ok": True})

    def do_DELETE(self):
        if not self._host_ok() or "X-Gyra" not in self.headers:
            return self._json(403, {"error": "forbidden"})
        p = self._bank_path()
        if not p:
            return self._json(400, {"error": "bad bank name"})
        try:
            os.remove(p)
        except FileNotFoundError:
            pass
        return self._json(200, {"ok": True})


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print("Gyra at http://127.0.0.1:%d  (banks in %s)" % (port, BANKS))
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
