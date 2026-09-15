import { useState } from 'react'
import type { MouseEvent, ReactNode } from 'react'

type SortValue = string | number | boolean | null | undefined
type SortDirection = 'asc' | 'desc'

export interface Column<T> {
  key: string
  header: string
  render: (row: T) => ReactNode
  align?: 'right'
  /** Makes the column sortable by this value. */
  sortValue?: (row: T) => SortValue
}

interface DataTableProps<T> {
  columns: Column<T>[]
  rows: T[]
  rowKey: (row: T) => string | number
  onRowClick?: (row: T) => void
  empty?: string
  initialSort?: { key: string; direction: SortDirection }
}

export function DataTable<T>({
  columns,
  rows,
  rowKey,
  onRowClick,
  empty = 'Nothing to show.',
  initialSort,
}: DataTableProps<T>) {
  const [sort, setSort] = useState(initialSort ?? null)

  if (rows.length === 0) return <p className="empty">{empty}</p>

  const sortValue = sort ? columns.find((column) => column.key === sort.key)?.sortValue : undefined
  const sortedRows =
    sort && sortValue ? [...rows].sort((a, b) => compareValues(sortValue(a), sortValue(b), sort.direction)) : rows

  function toggleSort(column: Column<T>) {
    setSort((current) =>
      current?.key === column.key
        ? { key: column.key, direction: current.direction === 'asc' ? 'desc' : 'asc' }
        : { key: column.key, direction: column.align === 'right' ? 'desc' : 'asc' },
    )
  }

  function handleRowClick(event: MouseEvent<HTMLTableRowElement>, row: T) {
    // Links and controls inside the row keep their own behaviour.
    if ((event.target as HTMLElement).closest('a, button, input, select')) return
    onRowClick?.(row)
  }

  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr>
            {columns.map((column) => {
              const direction = sort?.key === column.key ? sort.direction : undefined
              return (
                <th
                  key={column.key}
                  scope="col"
                  className={column.align === 'right' ? 'num' : undefined}
                  aria-sort={direction === 'asc' ? 'ascending' : direction === 'desc' ? 'descending' : undefined}
                >
                  {column.sortValue ? (
                    <button type="button" className="sort-button" onClick={() => toggleSort(column)}>
                      {column.header}
                      <span className="sort-indicator" aria-hidden="true">
                        {direction === 'asc' ? '↑' : direction === 'desc' ? '↓' : ''}
                      </span>
                    </button>
                  ) : (
                    column.header
                  )}
                </th>
              )
            })}
          </tr>
        </thead>
        <tbody>
          {sortedRows.map((row) => (
            <tr
              key={rowKey(row)}
              className={onRowClick ? 'is-clickable' : undefined}
              onClick={onRowClick ? (event) => handleRowClick(event, row) : undefined}
            >
              {columns.map((column) => (
                <td key={column.key} className={column.align === 'right' ? 'num' : undefined}>
                  {column.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function compareValues(a: SortValue, b: SortValue, direction: SortDirection): number {
  const aMissing = a === null || a === undefined
  const bMissing = b === null || b === undefined
  // Blanks sort last in either direction.
  if (aMissing || bMissing) return aMissing === bMissing ? 0 : aMissing ? 1 : -1
  const order = typeof a === 'string' && typeof b === 'string' ? a.localeCompare(b) : Number(a) - Number(b)
  return direction === 'asc' ? order : -order
}
