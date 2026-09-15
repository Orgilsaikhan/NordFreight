import type { ReactNode } from 'react'

interface StatTileProps {
  label: string
  value: ReactNode
  meta?: ReactNode
  /** Colours the meta line when it describes a change that is good or bad. */
  trend?: 'good' | 'bad'
}

export function StatTile({ label, value, meta, trend }: StatTileProps) {
  return (
    <div className="stat">
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
      {meta && <div className={trend ? `stat-meta trend-${trend}` : 'stat-meta'}>{meta}</div>}
    </div>
  )
}
