import json
import os
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NOTES = []
LOCK = threading.Lock()
MAX_NOTES = 100
MAX_LEN = 280


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/api/health":
            self._send(200, {"status": "ok"})
        elif self.path == "/api/notes":
            with LOCK:
                self._send(200, {"pod": socket.gethostname(), "notes": NOTES})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/notes":
            return self._send(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            text = json.loads(self.rfile.read(min(length, 4096)))["text"].strip()
        except (ValueError, KeyError, AttributeError, TypeError):
            return self._send(400, {"error": 'expected JSON {"text": "..."}'})
        if not text or len(text) > MAX_LEN:
            return self._send(400, {"error": f"text must be 1-{MAX_LEN} chars"})
        with LOCK:
            NOTES.insert(0, {"text": text})
            del NOTES[MAX_NOTES:]
        self._send(201, {"text": text})

    def do_DELETE(self):
        if self.path != "/api/notes":
            return self._send(404, {"error": "not found"})
        with LOCK:
            NOTES.clear()
        self._send(200, {"deleted": True})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    ThreadingHTTPServer(("", port), Handler).serve_forever()
