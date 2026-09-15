import type { ReactNode } from 'react'

export function Fields({ children }: { children: ReactNode }) {
  return <dl className="fields">{children}</dl>
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="field">
      <dt>{label}</dt>
      <dd>{children}</dd>
    </div>
  )
}
