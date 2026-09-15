import type { CellValue, ColumnInfo } from './types'

export const INTEGER_TYPES = new Set(['tinyint', 'smallint', 'int', 'bigint'])
export const DECIMAL_TYPES = new Set(['decimal', 'numeric', 'money', 'smallmoney', 'float', 'real'])
export const NUMERIC_TYPES = new Set([...INTEGER_TYPES, ...DECIMAL_TYPES])
export const DATETIME_TYPES = new Set(['datetime', 'datetime2', 'smalldatetime'])
export const STRING_TYPES = new Set(['char', 'varchar', 'text', 'nchar', 'nvarchar', 'ntext'])

/** Link to the edit form for one row, identified by its primary-key values. */
export function rowEditorPath(table: string, key: Record<string, CellValue>): string {
  const query = new URLSearchParams()
  for (const [column, value] of Object.entries(key)) query.set(column, String(value))
  return `/data/${encodeURIComponent(table)}/row?${query}`
}

/** The text an input shows for a stored value; empty means NULL. */
export function toInputValue(column: ColumnInfo, value: CellValue): string {
  if (value === null) return ''
  if (typeof value === 'boolean') return value ? '1' : '0'
  const text = String(value)
  if (column.type === 'date') return text.slice(0, 10)
  if (DATETIME_TYPES.has(column.type)) return text.slice(0, 19)
  return text
}

/** "nvarchar(200), NULL", "decimal(12,2)", "rowversion". */
export function typeLabel(column: ColumnInfo): string {
  let label = column.row_version ? 'rowversion' : column.type
  if (STRING_TYPES.has(column.type)) label += `(${column.max_length ?? 'max'})`
  else if (column.type === 'decimal' || column.type === 'numeric') label += `(${column.precision},${column.scale})`
  return column.nullable ? `${label}, NULL` : label
}

/** Why a column can't be edited, or null when it can. */
export function readOnlyReason(column: ColumnInfo): string | null {
  if (column.primary_key) return 'Анхдагч түлхүүр тул засагдахгүй'
  if (column.computed) return 'Бусад баганаас тооцоологдоно'
  if (column.row_version) return 'Мөр өөрчлөгдөх бүрт автоматаар шинэчлэгдэнэ'
  if (column.identity) return 'Автоматаар дугаарлагдана'
  return null
}
