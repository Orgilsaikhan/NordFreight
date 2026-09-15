import { humanize } from '../format'
import { toneOf } from '../status'

export function StatusBadge({ value }: { value: string }) {
  return (
    <span className="badge">
      <span className="dot" data-tone={toneOf(value)} aria-hidden="true" />
      {humanize(value)}
    </span>
  )
}
