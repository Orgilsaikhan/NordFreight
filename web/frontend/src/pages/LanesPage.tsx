import { useNavigate } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Loadable } from '../components/States'
import { rowEditorPath } from '../dataEditor'
import * as fmt from '../format'
import type { Lane } from '../types'
import { useApi } from '../useApi'

const columns: Column<Lane>[] = [
  {
    key: 'lane',
    header: 'Lane',
    render: (lane) => (
      <>
        {lane.LaneName.replace('->', '→')}
        {!lane.IsActive && <span className="tag">Идэвхгүй</span>}
      </>
    ),
    sortValue: (lane) => lane.LaneName,
  },
  {
    key: 'distance',
    header: 'Distance',
    align: 'right',
    render: (lane) => `${fmt.num(lane.DistanceKm)} км`,
    sortValue: (lane) => lane.DistanceKm,
  },
  {
    key: 'driveTime',
    header: 'Drive time',
    align: 'right',
    render: (lane) => `${fmt.num(lane.EstimatedDrivingHours, 1)} цаг`,
    sortValue: (lane) => lane.EstimatedDrivingHours,
  },
  {
    key: 'shipments',
    header: 'Shipments',
    align: 'right',
    render: (lane) => fmt.num(lane.ShipmentCount),
    sortValue: (lane) => lane.ShipmentCount,
  },
  {
    key: 'revenue',
    header: 'Revenue',
    align: 'right',
    render: (lane) => fmt.money(lane.TotalRevenue),
    sortValue: (lane) => lane.TotalRevenue,
  },
  {
    key: 'perKm',
    header: 'Revenue / km',
    align: 'right',
    render: (lane) => fmt.money(lane.TotalRevenuePerKm),
    sortValue: (lane) => lane.TotalRevenuePerKm,
  },
  {
    key: 'onTime',
    header: 'On time',
    align: 'right',
    render: (lane) => fmt.percent(lane.OnTimePercentage),
    sortValue: (lane) => lane.OnTimePercentage,
  },
  { key: 'late', header: 'Late', align: 'right', render: (lane) => fmt.num(lane.LateCount), sortValue: (lane) => lane.LateCount },
  {
    key: 'transit',
    header: 'Avg transit',
    align: 'right',
    render: (lane) => (lane.AvgActualTransitDays == null ? '—' : `${fmt.num(lane.AvgActualTransitDays, 1)} хоног`),
    sortValue: (lane) => lane.AvgActualTransitDays,
  },
]

export function LanesPage() {
  const navigate = useNavigate()
  const state = useApi<Lane[]>('/lanes')

  return (
    <>
      <PageHeader title="Чиглэлүүд" subtitle="Терминал хоорондын ачаа, орлого, хугацааны гүйцэтгэл. Мөр дээр дарж засна." />
      <Card>
        <Loadable state={state}>
          {(lanes) => (
            <DataTable
              columns={columns}
              rows={lanes}
              rowKey={(lane) => lane.LaneId}
              onRowClick={(lane) => navigate(rowEditorPath('Lanes', { LaneId: lane.LaneId }))}
              initialSort={{ key: 'revenue', direction: 'desc' }}
            />
          )}
        </Loadable>
      </Card>
    </>
  )
}
