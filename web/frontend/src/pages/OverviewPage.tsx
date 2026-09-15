import { Link } from 'react-router'
import { Card } from '../components/Card'
import { CategoryBars } from '../components/CategoryBars'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { RevenueChart } from '../components/RevenueChart'
import { Loadable } from '../components/States'
import { StatTile } from '../components/StatTile'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import type { AtRiskShipment, Overview } from '../types'
import { useApi } from '../useApi'

const riskColumns: Column<AtRiskShipment>[] = [
  {
    key: 'tracking',
    header: 'Tracking',
    render: (shipment) => <Link to={`/shipments/${shipment.ShipmentId}`}>{shipment.TrackingNumber}</Link>,
  },
  {
    key: 'customer',
    header: 'Customer',
    render: (shipment) => (
      <>
        {shipment.CustomerName}
        <span className="cell-sub">{`${shipment.OriginTerminal} → ${shipment.DestinationTerminal}`}</span>
      </>
    ),
  },
  { key: 'promised', header: 'Promised', render: (shipment) => fmt.date(shipment.PromisedDeliveryDate) },
  { key: 'risk', header: 'Risk', render: (shipment) => <StatusBadge value={shipment.RiskLevel} /> },
]

export function OverviewPage() {
  const state = useApi<Overview>('/overview')

  return (
    <>
      <PageHeader title="Overview" subtitle={`Freight operations as of ${fmt.date(fmt.todayUtc())}`} />
      <Loadable state={state}>{(data) => <OverviewContent data={data} />}</Loadable>
    </>
  )
}

function OverviewContent({ data }: { data: Overview }) {
  const { kpis, revenue_trend: trend } = data
  const current = trend.at(-1)
  const growth = current?.RevenueGrowthPct ?? null
  const atRisk = data.risk_counts.reduce((sum, entry) => sum + entry.Shipments, 0)
  const breached = data.risk_counts.find((entry) => entry.RiskLevel === 'Breached')?.Shipments ?? 0

  return (
    <div className="stack">
      <div className="kpis">
        <StatTile
          label="Revenue this month"
          value={fmt.compactMoney(current?.TotalRevenue)}
          meta={growth === null ? undefined : `${growth >= 0 ? '▲' : '▼'} ${fmt.percent(Math.abs(growth))} vs last month`}
          trend={growth === null ? undefined : growth >= 0 ? 'good' : 'bad'}
        />
        <StatTile
          label="Open shipments"
          value={fmt.num(kpis.OpenShipments)}
          meta={`${fmt.num(kpis.ExceptionShipments)} in exception`}
        />
        <StatTile label="On-time delivery" value={fmt.percent(kpis.OnTimePct90d)} meta="Delivered in the last 90 days" />
        <StatTile
          label="Outstanding receivables"
          value={fmt.compactMoney(kpis.OutstandingBalance)}
          meta={`${fmt.plural(kpis.OverdueInvoices, 'invoice')} overdue`}
        />
        <StatTile label="Shipments at risk" value={fmt.num(atRisk)} meta={`${fmt.num(breached)} past their promised date`} />
      </div>

      <RevenueChart data={trend} />

      <div className="grid-split">
        <Card
          title="Shipments at risk"
          subtitle="Still moving and due within two days, or already late"
          actions={
            <Link className="small" to="/shipments">
              All shipments
            </Link>
          }
        >
          <DataTable
            columns={riskColumns}
            rows={data.at_risk}
            rowKey={(shipment) => shipment.ShipmentId}
            empty="No shipments are at risk."
          />
        </Card>
        <Card title="Revenue by cargo category" subtitle="All time">
          <CategoryBars rows={data.categories} />
        </Card>
      </div>
    </div>
  )
}
