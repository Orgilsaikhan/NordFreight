import { Link, useNavigate } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Loadable } from '../components/States'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import type { CustomerRow } from '../types'
import { useApi } from '../useApi'

const columns: Column<CustomerRow>[] = [
  {
    key: 'name',
    header: 'Customer',
    render: (customer) => (
      <>
        <Link to={`/customers/${customer.CustomerId}`}>{customer.LegalName}</Link>
        <span className="cell-sub">{customer.CustomerCode}</span>
      </>
    ),
    sortValue: (customer) => customer.LegalName,
  },
  {
    key: 'status',
    header: 'Status',
    render: (customer) => <StatusBadge value={customer.IsActive ? 'Active' : 'Inactive'} />,
    sortValue: (customer) => customer.IsActive,
  },
  {
    key: 'shipments',
    header: 'Shipments',
    align: 'right',
    render: (customer) => fmt.num(customer.TotalShipments),
    sortValue: (customer) => customer.TotalShipments,
  },
  {
    key: 'open',
    header: 'Open',
    align: 'right',
    render: (customer) => fmt.num(customer.OpenShipments),
    sortValue: (customer) => customer.OpenShipments,
  },
  {
    key: 'revenue',
    header: 'Lifetime revenue',
    align: 'right',
    render: (customer) => fmt.money(customer.LifetimeRevenue),
    sortValue: (customer) => customer.LifetimeRevenue,
  },
  {
    key: 'onTime',
    header: 'On time',
    align: 'right',
    render: (customer) => fmt.percent(customer.OnTimePercentage),
    sortValue: (customer) => customer.OnTimePercentage,
  },
  {
    key: 'outstanding',
    header: 'Outstanding',
    align: 'right',
    render: (customer) => fmt.money(customer.OutstandingBalance),
    sortValue: (customer) => customer.OutstandingBalance,
  },
  {
    key: 'last',
    header: 'Last pickup',
    render: (customer) => fmt.date(customer.LastShipmentDate),
    sortValue: (customer) => customer.LastShipmentDate,
  },
]

export function CustomersPage() {
  const navigate = useNavigate()
  const state = useApi<CustomerRow[]>('/customers')

  return (
    <>
      <PageHeader title="Харилцагчид" subtitle="Нийт орлогоор эрэмбэлсэн харилцагчид" />
      <Card>
        <Loadable state={state}>
          {(rows) => (
            <DataTable
              columns={columns}
              rows={rows}
              rowKey={(customer) => customer.CustomerId}
              onRowClick={(customer) => navigate(`/customers/${customer.CustomerId}`)}
              initialSort={{ key: 'revenue', direction: 'desc' }}
            />
          )}
        </Loadable>
      </Card>
    </>
  )
}
