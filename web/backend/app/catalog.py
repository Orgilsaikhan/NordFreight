"""The table catalog behind the data editor, read from SQL Server's system views.

Table and column names reach SQL text only after being looked up in this catalog, and every
value travels as a parameter.
"""

import re
import time
from dataclasses import dataclass
from datetime import date, datetime
from datetime import time as time_of_day
from decimal import Decimal, InvalidOperation
from typing import Any

import pyodbc

CACHE_SECONDS = 300

INTEGER_TYPES = {"tinyint", "smallint", "int", "bigint"}
DECIMAL_TYPES = {"decimal", "numeric", "money", "smallmoney"}
FLOAT_TYPES = {"float", "real"}
STRING_TYPES = {"char", "varchar", "text", "nchar", "nvarchar", "ntext"}
DATETIME_TYPES = {"datetime", "datetime2", "smalldatetime"}

CATALOG_SQL = """
SELECT t.name AS table_name, c.name AS column_name, ty.name AS type_name,
       c.max_length, c.precision, c.scale, c.is_nullable, c.is_identity, c.is_computed,
       CAST(IIF(ic.column_id IS NULL, 0, 1) AS bit) AS is_primary_key,
       rt.name AS ref_table, rc.name AS ref_column
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
JOIN sys.columns AS c ON c.object_id = t.object_id
JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.indexes AS pk ON pk.object_id = t.object_id AND pk.is_primary_key = 1
LEFT JOIN sys.index_columns AS ic
       ON ic.object_id = pk.object_id AND ic.index_id = pk.index_id AND ic.column_id = c.column_id
LEFT JOIN sys.foreign_key_columns AS fkc
       ON fkc.parent_object_id = t.object_id AND fkc.parent_column_id = c.column_id
LEFT JOIN sys.tables AS rt ON rt.object_id = fkc.referenced_object_id
LEFT JOIN sys.columns AS rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id
WHERE s.name = 'dbo' AND t.is_ms_shipped = 0
ORDER BY t.name, c.column_id;
"""


class InvalidValue(ValueError):
    """A value that doesn't fit its column. The message is shown to the user."""


@dataclass(frozen=True)
class Column:
    name: str
    type: str
    max_length: int | None  # in characters; None when unlimited or not text
    precision: int
    scale: int
    nullable: bool
    primary_key: bool
    identity: bool
    computed: bool
    references: tuple[str, str] | None  # (table, column)

    @property
    def row_version(self) -> bool:
        return self.type in ("timestamp", "rowversion")

    @property
    def editable(self) -> bool:
        return not (self.primary_key or self.identity or self.computed or self.row_version)

    def describe(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "type": self.type,
            "max_length": self.max_length,
            "precision": self.precision,
            "scale": self.scale,
            "nullable": self.nullable,
            "primary_key": self.primary_key,
            "identity": self.identity,
            "computed": self.computed,
            "row_version": self.row_version,
            "editable": self.editable,
            "references": {"table": self.references[0], "column": self.references[1]} if self.references else None,
        }


@dataclass(frozen=True)
class Table:
    name: str
    columns: tuple[Column, ...]

    @property
    def primary_key(self) -> list[Column]:
        return [column for column in self.columns if column.primary_key]

    @property
    def row_version(self) -> Column | None:
        return next((column for column in self.columns if column.row_version), None)

    def column(self, name: str) -> Column | None:
        return next((column for column in self.columns if column.name == name), None)

    def describe(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "primary_key": [column.name for column in self.primary_key],
            "columns": [column.describe() for column in self.columns],
        }


_cache: tuple[float, dict[str, Table]] | None = None


def load_catalog(conn: pyodbc.Connection) -> dict[str, Table]:
    """User tables in the dbo schema, cached for a few minutes."""
    global _cache
    if _cache and time.monotonic() - _cache[0] < CACHE_SECONDS:
        return _cache[1]
    columns: dict[str, list[Column]] = {}
    for row in conn.execute(CATALOG_SQL).fetchall():
        max_chars = None
        if row.type_name in STRING_TYPES and row.max_length != -1:
            max_chars = row.max_length // 2 if row.type_name.startswith("n") else row.max_length
        columns.setdefault(row.table_name, []).append(
            Column(
                name=row.column_name,
                type=row.type_name,
                max_length=max_chars,
                precision=row.precision,
                scale=row.scale,
                nullable=bool(row.is_nullable),
                primary_key=bool(row.is_primary_key),
                identity=bool(row.is_identity),
                computed=bool(row.is_computed),
                references=(row.ref_table, row.ref_column) if row.ref_table else None,
            )
        )
    catalog = {name: Table(name, tuple(table_columns)) for name, table_columns in columns.items()}
    _cache = (time.monotonic(), catalog)
    return catalog


def quote(name: str) -> str:
    """Brackets a table or column name that came from the catalog."""
    return "[" + name.replace("]", "]]") + "]"


def to_sql_value(column: Column, raw: Any) -> Any:
    """Converts a value sent by the browser into what pyodbc should bind for this column."""
    if raw is None or (isinstance(raw, str) and raw.strip() == ""):
        if not column.nullable:
            raise InvalidValue("Утга хоосон байж болохгүй.")
        return None
    if column.type in STRING_TYPES:
        text = str(raw)
        if column.max_length is not None and len(text) > column.max_length:
            raise InvalidValue(f"Хамгийн ихдээ {column.max_length} тэмдэгт.")
        return text
    text = str(raw).strip()
    try:
        if column.type in INTEGER_TYPES:
            if isinstance(raw, bool) or not re.fullmatch(r"-?\d+", text):
                raise InvalidValue("Бүхэл тоо оруулна уу.")
            return int(text)
        if column.type in DECIMAL_TYPES:
            number = Decimal(text)
            if not number.is_finite():
                raise InvalidValue("Тоо оруулна уу.")
            return number
        if column.type in FLOAT_TYPES:
            return float(text)
        if column.type == "bit":
            if isinstance(raw, bool):
                return raw
            if text.lower() in ("1", "true"):
                return True
            if text.lower() in ("0", "false"):
                return False
            raise InvalidValue("0 эсвэл 1 байх ёстой.")
        if column.type == "date":
            return date.fromisoformat(text[:10])
        if column.type in DATETIME_TYPES:
            return datetime.fromisoformat(text.removesuffix("Z"))
        if column.type == "time":
            return time_of_day.fromisoformat(text)
    except InvalidValue:
        raise
    except (InvalidOperation, ValueError):
        if column.type == "date":
            raise InvalidValue("Огноог ОООО-СС-ӨӨ хэлбэрээр оруулна уу.") from None
        if column.type in DATETIME_TYPES or column.type == "time":
            raise InvalidValue("Огноо, цагийг зөв оруулна уу.") from None
        raise InvalidValue("Тоо оруулна уу.") from None
    raise InvalidValue(f"{column.type} төрлийн утгыг засах боломжгүй.")


def to_json_value(value: Any) -> Any:
    """Keeps exact decimals and binary row versions intact on the way to the browser."""
    if isinstance(value, (bytes, bytearray)):
        return "0x" + bytes(value).hex().upper()
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (datetime, date, time_of_day)):
        return value.isoformat()
    return value


def parse_row_version(text: str) -> bytes:
    return bytes.fromhex(text[2:] if text[:2].lower() == "0x" else text)
