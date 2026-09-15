import { useEffect } from 'react'
import type { ReactNode } from 'react'
import { Link } from 'react-router'

interface PageHeaderProps {
  title: string
  subtitle?: ReactNode
  actions?: ReactNode
  back?: { to: string; label: string }
}

export function PageHeader({ title, subtitle, actions, back }: PageHeaderProps) {
  useEffect(() => {
    document.title = `${title} · NordFreight`
  }, [title])

  return (
    <header className="page-header">
      <div>
        {back && (
          <Link className="back-link" to={back.to}>
            ← {back.label}
          </Link>
        )}
        <h1>{title}</h1>
        {subtitle && <p className="subtitle">{subtitle}</p>}
      </div>
      {actions && <div className="page-actions">{actions}</div>}
    </header>
  )
}
