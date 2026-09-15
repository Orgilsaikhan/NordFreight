import { useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router'

const NAV_ITEMS = [
  { to: '/', label: 'Overview' },
  { to: '/shipments', label: 'Shipments' },
  { to: '/customers', label: 'Customers' },
  { to: '/invoices', label: 'Invoices' },
  { to: '/fleet', label: 'Fleet' },
  { to: '/drivers', label: 'Drivers' },
  { to: '/lanes', label: 'Lanes' },
]

export function Layout() {
  const { pathname } = useLocation()

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [pathname])

  return (
    <div className="app">
      <aside className="sidebar">
        <Link to="/" className="brand">
          <span className="brand-mark" aria-hidden="true" />
          NordFreight
        </Link>
        <nav className="nav" aria-label="Main">
          {NAV_ITEMS.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.to === '/'}>
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  )
}
