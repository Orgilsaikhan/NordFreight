import { useLayoutEffect, useRef, useState } from 'react'
import * as fmt from '../format'
import type { MonthlyRevenue } from '../types'
import { Card } from './Card'
import { DataTable, type Column } from './DataTable'

const PLOT_HEIGHT = 220
const TOP = 24 // room for the direct label above the tallest column
const AXIS_BAND = 28 // month labels live inside the SVG, so the card never clips them
const LEFT = 56
const RIGHT = 8
const MAX_BAR_WIDTH = 24
const CORNER = 4
const MIN_LABEL_SPACING = 56

const tableColumns: Column<MonthlyRevenue>[] = [
  { key: 'month', header: 'Month', render: (point) => fmt.month(point.MonthStart) },
  { key: 'revenue', header: 'Revenue', align: 'right', render: (point) => fmt.money(point.TotalRevenue) },
  { key: 'shipments', header: 'Shipments', align: 'right', render: (point) => fmt.num(point.ShipmentCount) },
  {
    key: 'change',
    header: 'Change',
    align: 'right',
    render: (point) =>
      point.RevenueGrowthPct == null
        ? '—'
        : `${point.RevenueGrowthPct > 0 ? '+' : ''}${fmt.percent(point.RevenueGrowthPct)}`,
  },
]

export function RevenueChart({ data }: { data: MonthlyRevenue[] }) {
  const [view, setView] = useState<'chart' | 'table'>('chart')

  return (
    <Card
      title="Monthly revenue"
      subtitle={`Last ${data.length} months`}
      actions={
        <button
          type="button"
          className="button small ghost"
          onClick={() => setView(view === 'chart' ? 'table' : 'chart')}
        >
          {view === 'chart' ? 'Show table' : 'Show chart'}
        </button>
      }
    >
      {view === 'chart' ? (
        <Columns data={data} />
      ) : (
        <DataTable columns={tableColumns} rows={[...data].reverse()} rowKey={(point) => point.MonthStart} />
      )}
    </Card>
  )
}

function Columns({ data }: { data: MonthlyRevenue[] }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(0)
  const [active, setActive] = useState<number | null>(null)

  useLayoutEffect(() => {
    const element = containerRef.current
    if (!element) return
    const observer = new ResizeObserver(([entry]) => setWidth(Math.floor(entry.contentRect.width)))
    observer.observe(element)
    return () => observer.disconnect()
  }, [])

  const height = TOP + PLOT_HEIGHT + AXIS_BAND
  const baseline = TOP + PLOT_HEIGHT
  const band = data.length > 0 ? Math.max(0, width - LEFT - RIGHT) / data.length : 0
  const barWidth = Math.min(MAX_BAR_WIDTH, band * 0.6)
  const step = niceStep(Math.max(0, ...data.map((point) => point.TotalRevenue)) / 4)
  const top = Math.max(step, Math.ceil(Math.max(0, ...data.map((point) => point.TotalRevenue)) / step) * step)
  const ticks = Array.from({ length: Math.round(top / step) + 1 }, (_, index) => index * step)
  const labelEvery = Math.max(1, Math.ceil(MIN_LABEL_SPACING / (band || 1)))
  const last = data.length - 1
  const y = (value: number) => baseline - (value / top) * PLOT_HEIGHT
  const barX = (index: number) => LEFT + index * band + (band - barWidth) / 2

  const activePoint = active === null ? null : data[active]
  const activeCenter = active === null ? 0 : LEFT + active * band + band / 2
  const tooltipOnLeft = activeCenter > width / 2

  return (
    <div className="chart" ref={containerRef}>
      {width > 0 && (
        <svg width={width} height={height} role="group" aria-label="Monthly revenue, one column per month">
          {ticks.map((tick) => (
            <g key={tick}>
              <line
                className={tick === 0 ? 'chart-baseline' : 'chart-grid'}
                x1={LEFT}
                x2={width - RIGHT}
                y1={y(tick)}
                y2={y(tick)}
              />
              <text className="chart-axis" x={LEFT - 8} y={y(tick)} dy="0.32em" textAnchor="end">
                {fmt.compactMoney(tick)}
              </text>
            </g>
          ))}

          {data.map((point, index) => (
            <g key={point.MonthStart}>
              <path
                className={index === active ? 'chart-bar is-active' : 'chart-bar'}
                d={columnPath(barX(index), y(point.TotalRevenue), barWidth, baseline - y(point.TotalRevenue))}
              />
              {(last - index) % labelEvery === 0 && (
                <text className="chart-axis" x={barX(index) + barWidth / 2} y={baseline + 18} textAnchor="middle">
                  {fmt.monthTick(point.MonthStart)}
                </text>
              )}
            </g>
          ))}

          {last >= 0 && active !== last && (
            <text
              className="chart-label"
              x={barX(last) + barWidth}
              y={y(data[last].TotalRevenue) - 8}
              textAnchor="end"
            >
              {fmt.compactMoney(data[last].TotalRevenue)}
            </text>
          )}

          {data.map((point, index) => (
            <rect
              key={point.MonthStart}
              className="chart-hit"
              x={LEFT + index * band}
              y={TOP}
              width={band}
              height={PLOT_HEIGHT}
              tabIndex={0}
              aria-label={`${fmt.month(point.MonthStart)}: ${fmt.money(point.TotalRevenue)} from ${fmt.plural(point.ShipmentCount, 'shipment')}`}
              onPointerEnter={() => setActive(index)}
              onPointerLeave={() => setActive(null)}
              onFocus={() => setActive(index)}
              onBlur={() => setActive(null)}
            />
          ))}
        </svg>
      )}

      {activePoint && (
        <div
          className="chart-tooltip"
          style={{
            top: Math.max(0, y(activePoint.TotalRevenue) - 24),
            ...(tooltipOnLeft ? { right: width - activeCenter + 16 } : { left: activeCenter + 16 }),
          }}
        >
          <strong>{fmt.money(activePoint.TotalRevenue)}</strong>
          <span>{fmt.month(activePoint.MonthStart)}</span>
          <span>{fmt.plural(activePoint.ShipmentCount, 'shipment')}</span>
        </div>
      )}
    </div>
  )
}

/** A column with rounded top corners and a square foot on the baseline. */
function columnPath(x: number, top: number, width: number, height: number): string {
  const r = Math.min(CORNER, width / 2, height)
  return `M${x},${top + height}V${top + r}Q${x},${top} ${x + r},${top}H${x + width - r}Q${x + width},${top} ${x + width},${top + r}V${top + height}Z`
}

/** Rounds a raw tick step up to 1, 2, 2.5 or 5 times a power of ten. */
function niceStep(raw: number): number {
  if (raw <= 0) return 1
  const power = 10 ** Math.floor(Math.log10(raw))
  const fraction = raw / power
  const nice = fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 2.5 ? 2.5 : fraction <= 5 ? 5 : 10
  return nice * power
}
