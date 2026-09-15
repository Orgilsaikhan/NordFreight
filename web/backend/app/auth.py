"""Sign-in for the website: user accounts, password hashes and sessions.

Accounts are kept in a small SQLite file beside the backend rather than in NordFreightDB,
so they survive `01 - Database Creation.sql` dropping and recreating the database.
Every signed-in user has the same rights.
"""

import hashlib
import hmac
import os
import secrets
import sqlite3
import time
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated

from fastapi import Cookie, Depends, HTTPException, status
from pydantic import BaseModel

AUTH_DB_PATH = Path(os.getenv("AUTH_DB_PATH") or Path(__file__).resolve().parents[1] / "data" / "auth.sqlite3")

# The account created the first time the store is empty.
INITIAL_USERNAME = os.getenv("INITIAL_ADMIN_USERNAME", "Admin")
INITIAL_PASSWORD = os.getenv("INITIAL_ADMIN_PASSWORD", "Admin123")

SESSION_COOKIE = "nordfreight_session"
SESSION_SECONDS = 12 * 60 * 60
# Set COOKIE_SECURE=true when the site is served over HTTPS.
COOKIE_SECURE = os.getenv("COOKIE_SECURE", "false").lower() == "true"

SCRYPT_N, SCRYPT_R, SCRYPT_P = 2**14, 8, 1

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY,
    username      TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    created_at    TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
);
"""


class User(BaseModel):
    id: int
    username: str


@contextmanager
def store() -> Iterator[sqlite3.Connection]:
    """A connection to the account store that commits on success and rolls back on error."""
    conn = sqlite3.connect(AUTH_DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def init_store() -> None:
    """Creates the tables and, when there are no accounts yet, the initial one."""
    AUTH_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with store() as conn:
        conn.executescript(SCHEMA)
        if conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0:
            add_user(conn, INITIAL_USERNAME, INITIAL_PASSWORD)


def add_user(conn: sqlite3.Connection, username: str, password: str) -> sqlite3.Row:
    created_at = datetime.now(UTC).replace(tzinfo=None).isoformat(timespec="seconds")
    return conn.execute(
        "INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?) RETURNING id, username, created_at",
        (username, hash_password(password), created_at),
    ).fetchone()


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=SCRYPT_N, r=SCRYPT_R, p=SCRYPT_P, dklen=32)
    return f"scrypt${SCRYPT_N}${SCRYPT_R}${SCRYPT_P}${salt.hex()}${digest.hex()}"


def verify_password(password: str, stored: str) -> bool:
    _, n, r, p, salt, expected = stored.split("$")
    digest = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=int(n), r=int(r), p=int(p), dklen=32)
    return hmac.compare_digest(digest.hex(), expected)


# Checked when the username doesn't exist, so a wrong username takes as long as a wrong password.
UNKNOWN_USER_HASH = hash_password(secrets.token_urlsafe(16))


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def start_session(conn: sqlite3.Connection, user_id: int) -> str:
    """Stores a new session and returns its token for the cookie. Only the token's hash is kept."""
    token = secrets.token_urlsafe(32)
    now = int(time.time())
    conn.execute("DELETE FROM sessions WHERE expires_at <= ?", (now,))
    conn.execute(
        "INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)",
        (token_hash(token), user_id, now + SESSION_SECONDS),
    )
    return token


SessionToken = Annotated[str | None, Cookie(alias=SESSION_COOKIE)]


def current_user(session: SessionToken = None) -> User:
    """Dependency: the signed-in user, or 401 when the request has no valid session."""
    if session:
        with store() as conn:
            row = conn.execute(
                """
                SELECT u.id, u.username
                FROM sessions AS s
                JOIN users AS u ON u.id = s.user_id
                WHERE s.token_hash = ? AND s.expires_at > ?
                """,
                (token_hash(session), int(time.time())),
            ).fetchone()
        if row:
            return User(id=row["id"], username=row["username"])
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sign in to continue.")


CurrentUser = Annotated[User, Depends(current_user)]
