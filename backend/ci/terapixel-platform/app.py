import hashlib
import json
import os
import re
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse


PORT = int(os.environ.get("PORT", "8080"))
DB_PATH = os.environ.get("DB_PATH", "/data/terapixel-platform.db")
GAME_ID = os.environ.get("TPX_GAME_ID", "color_crunch")
INTERNAL_SERVICE_KEY = os.environ.get("INTERNAL_SERVICE_KEY", "ci-internal-key")

DB_LOCK = threading.Lock()
DB = sqlite3.connect(DB_PATH, check_same_thread=False)
DB.row_factory = sqlite3.Row


def init_db() -> None:
    with DB_LOCK:
        DB.execute(
            """
            CREATE TABLE IF NOT EXISTS players (
                nakama_user_id TEXT PRIMARY KEY,
                player_id TEXT NOT NULL,
                session_token TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            );
            """
        )
        DB.execute(
            """
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at INTEGER NOT NULL
            );
            """
        )
        DB.execute(
            """
            CREATE TABLE IF NOT EXISTS coins (
                player_id TEXT PRIMARY KEY,
                balance INTEGER NOT NULL
            );
            """
        )
        DB.commit()


def now_unix() -> int:
    return int(time.time())


def stable_player_id(nakama_user_id: str) -> str:
    digest = hashlib.sha1(nakama_user_id.encode("utf-8")).hexdigest()[:16]
    return f"player_{digest}"


def parse_json(handler: BaseHTTPRequestHandler) -> dict:
    try:
        size = int(handler.headers.get("Content-Length", "0"))
    except ValueError:
        size = 0
    raw = handler.rfile.read(size) if size > 0 else b"{}"
    if not raw:
        return {}
    try:
        decoded = raw.decode("utf-8")
    except UnicodeDecodeError:
        return {}
    try:
        data = json.loads(decoded)
    except json.JSONDecodeError:
        return {}
    if isinstance(data, dict):
        return data
    return {}


def bearer_token(handler: BaseHTTPRequestHandler) -> str:
    auth = handler.headers.get("Authorization", "").strip()
    prefix = "Bearer "
    if not auth.startswith(prefix):
        return ""
    return auth[len(prefix) :].strip()


def token_to_player(token: str) -> tuple[str, str]:
    if not token.startswith("ci-session-"):
        return "", ""
    nakama_user_id = token[len("ci-session-") :].strip()
    if not nakama_user_id:
        return "", ""
    with DB_LOCK:
        row = DB.execute(
            "SELECT player_id FROM players WHERE nakama_user_id = ?",
            (nakama_user_id,),
        ).fetchone()
    if row is None:
        return nakama_user_id, ""
    return nakama_user_id, str(row["player_id"])


def ensure_coin_row(player_id: str) -> None:
    with DB_LOCK:
        DB.execute(
            "INSERT OR IGNORE INTO coins(player_id, balance) VALUES (?, ?)",
            (player_id, 0),
        )
        DB.commit()


def get_balance(player_id: str) -> int:
    with DB_LOCK:
        row = DB.execute(
            "SELECT balance FROM coins WHERE player_id = ?",
            (player_id,),
        ).fetchone()
    if row is None:
        return 0
    try:
        return max(0, int(row["balance"]))
    except (TypeError, ValueError):
        return 0


def set_balance(player_id: str, balance: int) -> int:
    safe_balance = max(0, int(balance))
    with DB_LOCK:
        DB.execute(
            "INSERT INTO coins(player_id, balance) VALUES(?, ?) "
            "ON CONFLICT(player_id) DO UPDATE SET balance = excluded.balance",
            (player_id, safe_balance),
        )
        DB.commit()
    return safe_balance


def adjust_balance(player_id: str, delta: int) -> int:
    balance = get_balance(player_id)
    return set_balance(player_id, balance + int(delta))


def entitlements_payload(balance: int) -> dict:
    return {"coins": {GAME_ID: {"balance": int(balance)}}}


def is_valid_username(value: str) -> bool:
    return bool(re.fullmatch(r"[a-z0-9_-]{3,20}", value or ""))


class Handler(BaseHTTPRequestHandler):
    server_version = "tpx-ci-platform/1.0"

    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _record_event(self, event_type: str, payload: dict) -> None:
        with DB_LOCK:
            DB.execute(
                "INSERT INTO events(event_type, payload, created_at) VALUES (?, ?, ?)",
                (event_type, json.dumps(payload), now_unix()),
            )
            DB.commit()

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            self._send(200, {"ok": True, "service": "terapixel-platform-mock"})
            return

        if path == "/v1/iap/entitlements":
            token = bearer_token(self)
            _, player_id = token_to_player(token)
            if not player_id:
                self._send(401, {"error": {"message": "missing or invalid bearer token"}})
                return
            self._send(200, entitlements_payload(get_balance(player_id)))
            return

        self._send(404, {"error": {"message": f"unknown path {path}"}})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        payload = parse_json(self)

        if path == "/v1/auth/verify":
            self._send(200, {"allowed": True})
            return

        if path == "/v1/events":
            self._record_event("platform_event", payload)
            self._send(200, {"ok": True})
            return

        if path == "/v1/telemetry/events":
            self._record_event("telemetry_event", payload)
            self._send(200, {"ok": True})
            return

        if path == "/v1/auth/nakama":
            nakama_user_id = str(payload.get("nakama_user_id", "")).strip()
            if not nakama_user_id:
                self._send(400, {"error": {"message": "nakama_user_id is required"}})
                return
            player_id = stable_player_id(nakama_user_id)
            session_token = f"ci-session-{nakama_user_id}"
            with DB_LOCK:
                DB.execute(
                    "INSERT INTO players(nakama_user_id, player_id, session_token, updated_at) "
                    "VALUES(?, ?, ?, ?) "
                    "ON CONFLICT(nakama_user_id) DO UPDATE SET "
                    "player_id = excluded.player_id, "
                    "session_token = excluded.session_token, "
                    "updated_at = excluded.updated_at",
                    (nakama_user_id, player_id, session_token, now_unix()),
                )
                DB.commit()
            ensure_coin_row(player_id)
            self._send(
                200,
                {
                    "session_token": session_token,
                    "player_id": player_id,
                    "game_id": GAME_ID,
                },
            )
            return

        if path == "/v1/iap/verify":
            token = bearer_token(self)
            _, player_id = token_to_player(token)
            if not player_id:
                self._send(401, {"error": {"message": "missing or invalid bearer token"}})
                return
            balance = get_balance(player_id)
            self._send(
                200,
                {
                    "ok": True,
                    "entitlements": entitlements_payload(balance),
                    "product_id": str(payload.get("product_id", "")),
                },
            )
            return

        if path == "/v1/iap/coins/adjust":
            token = bearer_token(self)
            _, player_id = token_to_player(token)
            if not player_id:
                self._send(401, {"error": {"message": "missing or invalid bearer token"}})
                return
            delta = int(payload.get("delta", 0))
            balance = adjust_balance(player_id, delta)
            self._send(
                200,
                {"ok": True, "entitlements": entitlements_payload(balance)},
            )
            return

        if path == "/v1/account/merge/code":
            self._send(
                200,
                {
                    "ok": True,
                    "merge_code": "CI-MERGE-CODE",
                    "expires_at": now_unix() + 600,
                },
            )
            return

        if path == "/v1/account/merge/redeem":
            self._send(200, {"ok": True, "merged": True})
            return

        if path == "/v1/account/magic-link/start":
            self._send(
                200,
                {"ok": True, "status": "sent", "expires_in_seconds": 600},
            )
            return

        if path == "/v1/account/magic-link/complete":
            self._send(
                200,
                {
                    "ok": True,
                    "status": "linked",
                    "completed": True,
                    "primaryProfileId": "ci_profile_1",
                    "email": "ci@example.com",
                },
            )
            return

        if path == "/v1/identity/internal/username/validate":
            supplied = self.headers.get("x-admin-key", "")
            if INTERNAL_SERVICE_KEY and supplied != INTERNAL_SERVICE_KEY:
                self._send(401, {"error": {"message": "invalid internal key"}})
                return
            username = str(payload.get("username", "")).strip().lower()
            allowed = is_valid_username(username)
            self._send(200, {"allowed": allowed})
            return

        self._send(404, {"error": {"message": f"unknown path {path}"}})

    def log_message(self, fmt: str, *args) -> None:
        return


def main() -> None:
    init_db()
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"terapixel-platform mock listening on :{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
