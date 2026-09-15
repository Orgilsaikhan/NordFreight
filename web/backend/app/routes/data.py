"""Generic data editor: browse any table and change any value except primary keys.

Changes are plain UPDATE statements, so the stored procedures' business rules don't run.
The database's own constraints and triggers still do.
"""

from typing import Annotated, Any

import pyodbc
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel

from ..catalog import (
    DATETIME_TYPES,
    INTEGER_TYPES,
    STRING_TYPES,
    InvalidValue,
    Table,
    load_catalog,
    parse_row_version,
    quote,
    to_json_value,
    to_sql_value,
)
from ..db import Connection, like_pattern

router = APIRouter(prefix="/data", tags=["data"])

# Foreign keys into tables larger than this get a number box instead of a dropdown.
OPTIONS_LIMIT = 500


class RowChanges(BaseModel):
    changes: dict[str, Any]
    # The RowVersion the form was loaded with, for tables that have one.
    row_version: str | None = None


def get_table(conn: pyodbc.Connection, name: str) -> Table:
    table = load_catalog(conn).get(name)
    if table is None:
        raise HTTPException(status_code=404, detail=f"Хүснэгт олдсонгүй: {name}")
    return table


def fetch_rows(conn: pyodbc.Connection, sql: str, params: list[Any]) -> list[dict[str, Any]]:
    cursor = conn.execute(sql, *params)
    names = [column[0] for column in cursor.description]
    return [{name: to_json_value(value) for name, value in zip(names, row)} for row in cursor.fetchall()]


def key_filter(table: Table, values: dict[str, Any]) -> tuple[str, list[Any]]:
    """WHERE clause and parameters that pick out one row by its primary key."""
    clauses, params = [], []
    for column in table.primary_key:
        if values.get(column.name) in (None, ""):
            raise HTTPException(status_code=422, detail=f"Анхдагч түлхүүрийн утга дутуу: {column.name}")
        try:
            params.append(to_sql_value(column, values[column.name]))
        except InvalidValue as exc:
            raise HTTPException(status_code=422, detail=f"{column.name}: {exc}") from None
        clauses.append(f"{quote(column.name)} = ?")
    return " AND ".join(clauses), params


@router.get("/tables")
def list_tables(conn: Connection):
    counts = {
        row.name: row.row_count
        for row in conn.execute(
            """
            SELECT t.name, SUM(p.rows) AS row_count
            FROM sys.tables AS t
            JOIN sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
            WHERE t.is_ms_shipped = 0
            GROUP BY t.name;
            """
        ).fetchall()
    }
    return [
        {
            "name": table.name,
            "row_count": counts.get(table.name, 0),
            "column_count": len(table.columns),
            "editable_count": sum(column.editable for column in table.columns),
            "primary_key": [column.name for column in table.primary_key],
        }
        for table in sorted(load_catalog(conn).values(), key=lambda table: table.name)
    ]


@router.get("/tables/{table_name}")
def describe_table(table_name: str, conn: Connection):
    return get_table(conn, table_name).describe()


@router.get("/tables/{table_name}/rows")
def list_rows(
    table_name: str,
    conn: Connection,
    q: str | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=200)] = 50,
):
    """Rows in primary-key order. `q` matches text columns, or an integer primary key exactly."""
    table = get_table(conn, table_name)
    clauses, params = [], []
    term = (q or "").strip()
    if term:
        for column in table.columns:
            if column.type in STRING_TYPES:
                clauses.append(f"{quote(column.name)} LIKE ?")
                params.append(like_pattern(term))
            elif column.primary_key and column.type in INTEGER_TYPES and term.lstrip("-").isdigit():
                clauses.append(f"{quote(column.name)} = ?")
                params.append(int(term))
    where = f"WHERE {' OR '.join(clauses)}" if clauses else ("WHERE 1 = 0" if term else "")
    source = f"FROM [dbo].{quote(table.name)} {where}"
    total = conn.execute(f"SELECT COUNT(*) {source};", *params).fetchone()[0]
    order = ", ".join(quote(column.name) for column in table.primary_key) or "(SELECT NULL)"
    columns = ", ".join(quote(column.name) for column in table.columns)
    rows = fetch_rows(
        conn,
        f"SELECT {columns} {source} ORDER BY {order} OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;",
        [*params, (page - 1) * page_size, page_size],
    )
    return {"rows": rows, "total": total}


@router.get("/tables/{table_name}/row")
def get_row(table_name: str, request: Request, conn: Connection):
    """One row; its primary-key values are passed as query parameters named after the columns."""
    table = get_table(conn, table_name)
    where, params = key_filter(table, dict(request.query_params))
    columns = ", ".join(quote(column.name) for column in table.columns)
    rows = fetch_rows(conn, f"SELECT {columns} FROM [dbo].{quote(table.name)} WHERE {where};", params)
    if not rows:
        raise HTTPException(status_code=404, detail="Мөр олдсонгүй.")
    return rows[0]


@router.patch("/tables/{table_name}/row")
def update_row(table_name: str, body: RowChanges, request: Request, conn: Connection):
    """Updates only the columns that changed and returns the row as it is now."""
    table = get_table(conn, table_name)
    if not body.changes:
        raise HTTPException(status_code=422, detail="Хадгалах өөрчлөлт алга.")

    assignments, params = [], []
    for name, raw in body.changes.items():
        column = table.column(name)
        if column is None:
            raise HTTPException(status_code=422, detail=f"Ийм багана алга: {name}")
        if not column.editable:
            raise HTTPException(status_code=422, detail=f"{name} баганыг засах боломжгүй.")
        try:
            params.append(to_sql_value(column, raw))
        except InvalidValue as exc:
            raise HTTPException(status_code=422, detail=f"{name}: {exc}") from None
        assignments.append(f"{quote(name)} = ?")

    # Keep UpdatedAt honest unless the user set it themselves.
    updated_at = table.column("UpdatedAt")
    if updated_at and updated_at.editable and updated_at.type in DATETIME_TYPES and "UpdatedAt" not in body.changes:
        assignments.append("[UpdatedAt] = SYSUTCDATETIME()")

    where, key_params = key_filter(table, dict(request.query_params))
    version_clause, version_params = "", []
    if table.row_version and body.row_version:
        try:
            version_params.append(parse_row_version(body.row_version))
        except ValueError:
            raise HTTPException(status_code=422, detail="RowVersion буруу байна.") from None
        version_clause = f" AND {quote(table.row_version.name)} = ?"

    cursor = conn.execute(
        f"UPDATE [dbo].{quote(table.name)} SET {', '.join(assignments)} WHERE {where}{version_clause};",
        *params,
        *key_params,
        *version_params,
    )
    if cursor.rowcount == 0:
        exists = conn.execute(f"SELECT 1 FROM [dbo].{quote(table.name)} WHERE {where};", *key_params).fetchone()
        if exists:
            raise HTTPException(
                status_code=409,
                detail="Таныг засаж байх хооронд энэ мөрийг өөр хүн өөрчилсөн байна. Хуудсаа дахин ачаалаад оролдоно уу.",
            )
        raise HTTPException(status_code=404, detail="Мөр олдсонгүй.")
    return get_row(table_name, request, conn)


@router.get("/tables/{table_name}/options")
def foreign_key_options(table_name: str, conn: Connection):
    """Dropdown choices for each foreign-key column; null where the referenced table is too large."""
    catalog = load_catalog(conn)
    table = get_table(conn, table_name)
    options: dict[str, list[dict[str, Any]] | None] = {}
    cached: dict[tuple[str, str], list[dict[str, Any]] | None] = {}
    for column in table.columns:
        if not column.references or column.references[0] not in catalog:
            continue
        if column.references not in cached:
            ref_table = catalog[column.references[0]]
            count = conn.execute(f"SELECT COUNT(*) FROM [dbo].{quote(ref_table.name)};").fetchone()[0]
            if count > OPTIONS_LIMIT:
                cached[column.references] = None
            else:
                labels = [c for c in ref_table.columns if c.type in STRING_TYPES and not c.primary_key][:2]
                if len(labels) == 2:
                    label_sql = f"CONCAT_WS(N' · ', {quote(labels[0].name)}, {quote(labels[1].name)})"
                elif labels:
                    label_sql = quote(labels[0].name)
                else:
                    label_sql = "NULL"
                value_sql = quote(column.references[1])
                order_sql = label_sql if labels else value_sql
                rows = conn.execute(
                    f"SELECT {value_sql} AS value, {label_sql} AS label FROM [dbo].{quote(ref_table.name)} ORDER BY {order_sql};"
                ).fetchall()
                cached[column.references] = [{"value": to_json_value(row.value), "label": row.label} for row in rows]
        options[column.name] = cached[column.references]
    return options
