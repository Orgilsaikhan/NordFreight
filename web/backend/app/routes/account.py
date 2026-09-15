import sqlite3
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field

from ..auth import (
    COOKIE_SECURE,
    SESSION_COOKIE,
    SESSION_SECONDS,
    UNKNOWN_USER_HASH,
    CurrentUser,
    SessionToken,
    add_user,
    current_user,
    hash_password,
    start_session,
    store,
    token_hash,
    verify_password,
)

router = APIRouter(tags=["account"])


class Credentials(BaseModel):
    username: Annotated[str, Field(min_length=1, max_length=64)]
    password: Annotated[str, Field(min_length=1, max_length=256)]


class PasswordChange(BaseModel):
    current_password: Annotated[str, Field(min_length=1, max_length=256)]
    new_password: Annotated[str, Field(min_length=8, max_length=256)]


class NewUser(BaseModel):
    username: Annotated[str, Field(min_length=3, max_length=64, pattern=r"^[A-Za-z0-9._-]+$")]
    password: Annotated[str, Field(min_length=8, max_length=256)]


@router.post("/auth/login")
def sign_in(credentials: Credentials, response: Response):
    with store() as conn:
        user = conn.execute(
            "SELECT id, username, password_hash FROM users WHERE username = ?",
            (credentials.username.strip(),),
        ).fetchone()
        password_ok = verify_password(credentials.password, user["password_hash"] if user else UNKNOWN_USER_HASH)
        if user is None or not password_ok:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Нэвтрэх нэр эсвэл нууц үг буруу байна."
            )
        token = start_session(conn, user["id"])
    response.set_cookie(
        SESSION_COOKIE,
        token,
        max_age=SESSION_SECONDS,
        httponly=True,
        samesite="lax",
        secure=COOKIE_SECURE,
        path="/",
    )
    return {"username": user["username"]}


@router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
def sign_out(response: Response, session: SessionToken = None):
    if session:
        with store() as conn:
            conn.execute("DELETE FROM sessions WHERE token_hash = ?", (token_hash(session),))
    response.delete_cookie(SESSION_COOKIE, path="/", httponly=True, samesite="lax", secure=COOKIE_SECURE)


@router.get("/auth/me")
def who_am_i(user: CurrentUser):
    return {"username": user.username}


@router.post("/auth/password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(change: PasswordChange, user: CurrentUser, session: SessionToken = None):
    with store() as conn:
        row = conn.execute("SELECT password_hash FROM users WHERE id = ?", (user.id,)).fetchone()
        if not verify_password(change.current_password, row["password_hash"]):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Одоогийн нууц үг буруу байна.")
        conn.execute("UPDATE users SET password_hash = ? WHERE id = ?", (hash_password(change.new_password), user.id))
        # Other browsers signed in to this account must sign in again with the new password.
        conn.execute("DELETE FROM sessions WHERE user_id = ? AND token_hash <> ?", (user.id, token_hash(session or "")))


@router.get("/users", dependencies=[Depends(current_user)])
def list_users():
    with store() as conn:
        rows = conn.execute("SELECT id, username, created_at FROM users ORDER BY username COLLATE NOCASE").fetchall()
    return [dict(row) for row in rows]


@router.post("/users", status_code=status.HTTP_201_CREATED, dependencies=[Depends(current_user)])
def create_user(new_user: NewUser):
    try:
        with store() as conn:
            row = add_user(conn, new_user.username, new_user.password)
    except sqlite3.IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"{new_user.username} нэртэй хэрэглэгч аль хэдийн бүртгэлтэй байна.",
        ) from None
    return dict(row)
