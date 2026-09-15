r"""Database access for the API.

The local SQL Server Express instance only accepts Shared Memory connections, so the
default server is lpc:.\SQLEXPRESS with Windows authentication. pyodbc pools
connections, which keeps one connection per request cheap.
"""

from __future__ import annotations

import os
import re
from collections.abc import Iterator
from typing import Annotated, Any

import pyodbc
from fastapi import Depends

SERVER = os.getenv("MSSQL_SERVER", r"lpc:.\SQLEXPRESS")
DATABASE = os.getenv("MSSQL_DATABASE", "NordFreightDB")
DRIVER = os.getenv("MSSQL_DRIVER", "ODBC Driver 18 for SQL Server")

CONNECTION_STRING = (
    f"Driver={{{DRIVER}}};Server={SERVER};Database={DATABASE};"
    "Trusted_Connection=yes;TrustServerCertificate=yes;APP=NordFreight Web"
)

# pyodbc messages end with "(<SQL Server error number>) (<ODBC function>)".
ERROR_NUMBER = re.compile(r"\((\d+)\)\s*\(SQL\w+\)")

Row = dict[str, Any]


def get_connection() -> Iterator[pyodbc.Connection]:
    # Autocommit, because the stored procedures open and commit their own transactions.
    conn = pyodbc.connect(CONNECTION_STRING, autocommit=True, timeout=10)
    try:
        yield conn
    finally:
        conn.close()


Connection = Annotated[pyodbc.Connection, Depends(get_connection)]


def to_dicts(cursor: pyodbc.Cursor) -> list[Row]:
    columns = [column[0] for column in cursor.description]
    return [dict(zip(columns, values)) for values in cursor.fetchall()]


def fetch_all(conn: pyodbc.Connection, sql: str, *params: Any) -> list[Row]:
    return to_dicts(conn.execute(sql, *params))


def fetch_one(conn: pyodbc.Connection, sql: str, *params: Any) -> Row | None:
    rows = fetch_all(conn, sql, *params)
    return rows[0] if rows else None


def result_sets(cursor: pyodbc.Cursor) -> list[list[Row]]:
    """Read every result set produced by a batch or procedure call."""
    sets = []
    while True:
        if cursor.description:
            sets.append(to_dicts(cursor))
        # After multi-statement batches nextset() can return an HY007 error object instead of raising.
        more = cursor.nextset()
        if not more or isinstance(more, pyodbc.Error):
            return sets


def like_pattern(text: str) -> str:
    """Wrap user text in % for LIKE, escaping LIKE wildcards."""
    escaped = text.strip().replace("[", "[[]").replace("%", "[%]").replace("_", "[_]")
    return f"%{escaped}%"


def describe_error(exc: pyodbc.Error) -> tuple[int | None, str]:
    """Return the SQL Server error number and the first message, without driver noise."""
    text = str(exc.args[-1]) if exc.args else str(exc)
    first = text.split("; ")[0]
    number = ERROR_NUMBER.search(first)
    first = re.sub(r"\[[0-9A-Z]{5}\] ", "", first)
    first = re.sub(r"\[Microsoft\]\[ODBC Driver \d+ for SQL Server\](?:\[SQL Server\])?", "", first)
    first = re.sub(r"\s*\(SQL\w+\)", "", first).strip()
    first = re.sub(r"\s*\(\d+\)$", "", first)
    return (int(number.group(1)) if number else None), first
