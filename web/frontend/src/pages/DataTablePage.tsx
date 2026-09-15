import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { Loadable } from '../components/States'
import { NUMERIC_TYPES, rowEditorPath } from '../dataEditor'
import { updateSearchParams } from '../searchParams'
import type { CellValue, ColumnInfo, DataRow, Page, TableInfo } from '../types'
import { useApi } from '../useApi'

const PAGE_SIZE = 50

export function DataTablePage() {
  const { table = '' } = useParams()
  const meta = useApi<TableInfo>(`/data/tables/${encodeURIComponent(table)}`)

  return (
    <>
      <PageHeader back={{ to: '/data', label: 'Өгөгдөл' }} title={table} subtitle="Засах мөрөө сонгоно уу" />
      <Loadable state={meta}>{(info) => <RowsView key={info.name} table={info} />}</Loadable>
    </>
  )
}

function RowsView({ table }: { table: TableInfo }) {
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const q = params.get('q') ?? ''
  const page = Math.max(1, Number(params.get('page')) || 1)
  const [search, setSearch] = useState(q)

  // Search once typing pauses rather than on every keystroke.
  useEffect(() => {
    if (search.trim() === q) return
    const timer = setTimeout(() => updateSearchParams(setParams, { q: search.trim(), page: '' }), 300)
    return () => clearTimeout(timer)
  }, [search, q, setParams])

  const query = new URLSearchParams({ page: String(page), page_size: String(PAGE_SIZE) })
  if (q) query.set('q', q)
  const rows = useApi<Page<DataRow>>(`/data/tables/${encodeURIComponent(table.name)}/rows?${query}`)

  const columns: Column<DataRow>[] = table.columns.map((column) => ({
    key: column.name,
    header: column.primary_key ? (
      <>
        {column.name}
        <span className="tag tag-key">PK</span>
      </>
    ) : (
      column.name
    ),
    align: NUMERIC_TYPES.has(column.type) ? ('right' as const) : undefined,
    render: (row: DataRow) => <Cell column={column} value={row[column.name]} />,
  }))
  const editableCount = table.columns.filter((column) => column.editable).length

  function keyOf(row: DataRow) {
    return Object.fromEntries(table.primary_key.map((name) => [name, row[name]]))
  }

  return (
    <>
      <div className="toolbar">
        <input
          className="input search"
          type="search"
          placeholder="Текст эсвэл дугаараар хайх"
          aria-label="Мөр хайх"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <span className="muted small">{`${table.columns.length} баганаас ${editableCount} нь засагдана`}</span>
      </div>
      <Card>
        <Loadable state={rows}>
          {(data) => (
            <>
              <DataTable
                columns={columns}
                rows={data.rows}
                rowKey={(row) => table.primary_key.map((name) => String(row[name])).join('|')}
                onRowClick={(row) => navigate(rowEditorPath(table.name, keyOf(row)))}
                empty="Мөр олдсонгүй."
              />
              <Pagination
                page={page}
                pageSize={PAGE_SIZE}
                total={data.total}
                onPage={(next) => updateSearchParams(setParams, { page: next > 1 ? String(next) : '' })}
              />
            </>
          )}
        </Loadable>
      </Card>
    </>
  )
}

function Cell({ column, value }: { column: ColumnInfo; value: CellValue }) {
  if (value === null) return <span className="null">NULL</span>
  if (typeof value === 'boolean') return <>{value ? '1' : '0'}</>
  const text = String(value)
  if (column.references) {
    // Foreign keys open the row they point to.
    return <Link to={rowEditorPath(column.references.table, { [column.references.column]: value })}>{text}</Link>
  }
  return text.length > 60 ? (
    <span className="cell-clip" title={text}>
      {text}
    </span>
  ) : (
    <>{text}</>
  )
}
