import * as fmt from '../format'
import type { CategoryRevenue } from '../types'

/** Revenue per cargo category. The categories are nominal, so every bar wears the same colour. */
export function CategoryBars({ rows }: { rows: CategoryRevenue[] }) {
  const max = Math.max(1, ...rows.map((row) => row.TotalRevenue))

  return (
    <ul className="hbars">
      <li className="hbar-row hbar-head" aria-hidden="true">
        <span>Category</span>
        <span />
        <span>Revenue</span>
        <span>Share</span>
      </li>
      {rows.map((row) => (
        <li key={row.CategoryName} className="hbar-row">
          <span className="hbar-label" title={row.CategoryName}>
            {row.CategoryName}
          </span>
          <span className="hbar-track">
            <span className="hbar" style={{ width: `${(row.TotalRevenue / max) * 100}%` }} />
          </span>
          <span className="hbar-value" title={fmt.money(row.TotalRevenue)}>
            {fmt.compactMoney(row.TotalRevenue)}
          </span>
          <span className="hbar-share">{fmt.percent(row.RevenueSharePct)}</span>
        </li>
      ))}
    </ul>
  )
}
