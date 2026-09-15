import { useEffect, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { Loadable } from '../components/States'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import { updateSearchParams } from '../searchParams'
import { SHIPMENT_STATUSES } from '../status'
import type { Page, ShipmentRow } from '../types'
import { useApi } from '../useApi'

const PAGE_SIZE = 25

const columns: Column<ShipmentRow>[] = [
  {
    key: 'tracking',
    header: 'Tracking',
    render: (shipment) => <Link to={`/shipments/${shipment.ShipmentId}`}>{shipment.TrackingNumber}</Link>,
  },
  { key: 'customer', header: 'Customer', render: (shipment) => shipment.CustomerName },
  { key: 'lane', header: 'Lane', render: (shipment) => `${shipment.OriginTerminal} → ${shipment.DestinationTerminal}` },
  { key: 'service', header: 'Service', render: (shipment) => shipment.ServiceCode },
  { key: 'pickup', header: 'Pickup', render: (shipment) => fmt.date(shipment.PickupDate) },
  { key: 'promised', header: 'Promised', render: (shipment) => fmt.date(shipment.PromisedDeliveryDate) },
  { key: 'delivery', header: 'Delivery', render: (shipment) => <StatusBadge value={shipment.DeliveryPerformance} /> },
  { key: 'status', header: 'Status', render: (shipment) => <StatusBadge value={shipment.Status} /> },
  { key: 'total', header: 'Total', align: 'right', render: (shipment) => fmt.money(shipment.TotalAmount) },
]

export function ShipmentsPage() {
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const q = params.get('q') ?? ''
  const status = params.get('status') ?? ''
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
  if (status) query.set('status', status)
  const state = useApi<Page<ShipmentRow>>(`/shipments?${query}`)

  return (
    <>
      <PageHeader
        title="Shipments"
        subtitle="Every booking, latest pickup first"
        actions={
          <Link className="button primary" to="/shipments/new">
            New shipment
          </Link>
        }
      />
      <div className="toolbar">
        <input
          className="input search"
          type="search"
          placeholder="Search tracking number or customer"
          aria-label="Search shipments"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <select
          className="select"
          aria-label="Filter by status"
          value={status}
          onChange={(event) => updateSearchParams(setParams, { status: event.target.value, page: '' })}
        >
          <option value="">All statuses</option>
          {SHIPMENT_STATUSES.map((value) => (
            <option key={value} value={value}>
              {fmt.humanize(value)}
            </option>
          ))}
        </select>
      </div>
      <Card>
        <Loadable state={state}>
          {(data) => (
            <>
              <DataTable
                columns={columns}
                rows={data.rows}
                rowKey={(shipment) => shipment.ShipmentId}
                onRowClick={(shipment) => navigate(`/shipments/${shipment.ShipmentId}`)}
                empty="No shipments match these filters."
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
