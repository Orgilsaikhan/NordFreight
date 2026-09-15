import { Link, useNavigate } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Loadable } from '../components/States'
import * as fmt from '../format'
import type { TableSummary } from '../types'
import { useApi } from '../useApi'

const columns: Column<TableSummary>[] = [
  {
    key: 'name',
    header: 'Table',
    render: (table) => <Link to={`/data/${encodeURIComponent(table.name)}`}>{table.name}</Link>,
    sortValue: (table) => table.name,
  },
  { key: 'rows', header: 'Rows', align: 'right', render: (table) => fmt.num(table.row_count), sortValue: (table) => table.row_count },
  {
    key: 'columns',
    header: 'Columns',
    align: 'right',
    render: (table) => fmt.num(table.column_count),
    sortValue: (table) => table.column_count,
  },
  {
    key: 'editable',
    header: 'Editable',
    align: 'right',
    render: (table) => fmt.num(table.editable_count),
    sortValue: (table) => table.editable_count,
  },
  { key: 'key', header: 'Primary key', render: (table) => table.primary_key.join(', ') },
]

export function DataTablesPage() {
  const navigate = useNavigate()
  const state = useApi<TableSummary[]>('/data/tables')

  return (
    <>
      <PageHeader
        title="Өгөгдөл"
        subtitle="Хүснэгтээ сонгоод мөрийг засна. Анхдагч түлхүүр, тооцоолсон багана засагдахгүй."
      />
      <Card>
        <Loadable state={state}>
          {(tables) => (
            <DataTable
              columns={columns}
              rows={tables}
              rowKey={(table) => table.name}
              onRowClick={(table) => navigate(`/data/${encodeURIComponent(table.name)}`)}
              initialSort={{ key: 'name', direction: 'asc' }}
            />
          )}
        </Loadable>
      </Card>
    </>
  )
}
