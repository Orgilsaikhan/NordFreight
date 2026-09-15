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
      <PageHeader title="Тойм" subtitle={`${fmt.date(fmt.todayUtc())}-ны байдлаар тээврийн үйл ажиллагаа`} />
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
          label="Энэ сарын орлого"
          value={fmt.compactMoney(current?.TotalRevenue)}
          meta={growth === null ? undefined : `${growth >= 0 ? '▲' : '▼'} ${fmt.percent(Math.abs(growth))} өмнөх сараас`}
          trend={growth === null ? undefined : growth >= 0 ? 'good' : 'bad'}
        />
        <StatTile
          label="Идэвхтэй ачаа"
          value={fmt.num(kpis.OpenShipments)}
          meta={`Асуудалтай: ${fmt.num(kpis.ExceptionShipments)}`}
        />
        <StatTile label="Хугацаандаа хүргэлт" value={fmt.percent(kpis.OnTimePct90d)} meta="Сүүлийн 90 хоногт хүргэсэн" />
        <StatTile
          label="Төлөгдөөгүй авлага"
          value={fmt.compactMoney(kpis.OutstandingBalance)}
          meta={`Хугацаа хэтэрсэн: ${fmt.count(kpis.OverdueInvoices, 'нэхэмжлэх')}`}
        />
        <StatTile label="Эрсдэлтэй ачаа" value={fmt.num(atRisk)} meta={`Амласан хугацаа хэтэрсэн: ${fmt.num(breached)}`} />
      </div>

      <RevenueChart data={trend} />

      <div className="grid-split">
        <Card
          title="Эрсдэлтэй ачаа"
          subtitle="Замд яваа, 2 хоногийн дотор хүргэх ёстой эсвэл хоцорсон ачаа"
          actions={
            <Link className="small" to="/shipments">
              Бүх ачаа
            </Link>
          }
        >
          <DataTable
            columns={riskColumns}
            rows={data.at_risk}
            rowKey={(shipment) => shipment.ShipmentId}
            empty="Эрсдэлтэй ачаа алга."
          />
        </Card>
        <Card title="Ачааны ангиллаар орлого" subtitle="Бүх хугацаанд">
          <CategoryBars rows={data.categories} />
        </Card>
      </div>
    </div>
  )
}
