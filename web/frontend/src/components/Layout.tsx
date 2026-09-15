import { useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router'
import { useAuth } from '../auth'

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
  const { username, signOut } = useAuth()

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
        <div className="sidebar-account">
          <NavLink to="/account" className="account-link" title="Account and users">
            <span className="avatar" aria-hidden="true">
              {username?.charAt(0).toUpperCase()}
            </span>
            <span className="account-name">{username}</span>
          </NavLink>
          <button type="button" className="button ghost small" onClick={() => void signOut()}>
            Sign out
          </button>
        </div>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  )
}
