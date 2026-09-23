#!/usr/bin/env python3
"""Tiny authenticated LAN address rendezvous service.
It never proxies SSH, Sunshine, or streaming traffic.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, os, threading, time, ipaddress

HOST = os.environ.get("DUTFLOW_HOST", "0.0.0.0")
PORT = int(os.environ.get("DUTFLOW_PORT", "18787"))
TOKEN = os.environ.get("DUTFLOW_TOKEN", "")
TTL = int(os.environ.get("DUTFLOW_TTL", "180"))
STATE_FILE = Path(os.environ.get("DUTFLOW_STATE", "/var/lib/dutflow/peers.json"))
state_lock = threading.Lock()


def load_state():
    try:
        return json.loads(STATE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, separators=(",", ":")))
    tmp.replace(STATE_FILE)


def authorized(handler):
    return TOKEN and handler.headers.get("Authorization", "") == f"Bearer {TOKEN}"


class Handler(BaseHTTPRequestHandler):
    server_version = "dutflow-rendezvous/1"

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {fmt % args}")

    def send_json(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/healthz":
            return self.send_json(200, {"ok": True})
        if self.path != "/v1/resolve" or not authorized(self):
            return self.send_json(404 if self.path != "/v1/resolve" else 401, {"error": "not found" if self.path != "/v1/resolve" else "unauthorized"})
        with state_lock:
            state = load_state()
            entry = state.get("local")
        if not entry or time.time() - entry["seen_at"] > TTL:
            return self.send_json(404, {"error": "local peer unavailable"})
        return self.send_json(200, {"ip": entry["ip"], "seen_at": entry["seen_at"], "expires_in": max(0, TTL - int(time.time() - entry["seen_at"]))})

    def do_POST(self):
        if self.path != "/v1/announce" or not authorized(self):
            return self.send_json(404 if self.path != "/v1/announce" else 401, {"error": "not found" if self.path != "/v1/announce" else "unauthorized"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length))
            ip = payload["ip"]
            if not isinstance(ip, str) or len(ip) > 64:
                raise ValueError
            ipaddress.ip_address(ip)
        except (ValueError, KeyError, json.JSONDecodeError):
            return self.send_json(400, {"error": "invalid ip"})
        with state_lock:
            state = load_state()
            state["local"] = {"ip": ip, "seen_at": int(time.time())}
            save_state(state)
        return self.send_json(204, {})


if not TOKEN:
    raise SystemExit("DUTFLOW_TOKEN is required")
print(f"dutflow rendezvous listening on {HOST}:{PORT}")
ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
