import type { ReactNode } from 'react'

interface CardProps {
  title?: ReactNode
  subtitle?: ReactNode
  actions?: ReactNode
  children: ReactNode
}

export function Card({ title, subtitle, actions, children }: CardProps) {
  return (
    <section className="card">
      {(title || actions) && (
        <header className="card-header">
          <div>
            {title && <h2 className="card-title">{title}</h2>}
            {subtitle && <p className="card-subtitle">{subtitle}</p>}
          </div>
          {actions && <div className="card-actions">{actions}</div>}
        </header>
      )}
      {children}
    </section>
  )
}
