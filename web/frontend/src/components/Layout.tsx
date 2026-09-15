import { useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router'
import { useAuth } from '../auth'

const NAV_ITEMS = [
  { to: '/', label: 'Тойм' },
  { to: '/shipments', label: 'Ачаа' },
  { to: '/customers', label: 'Харилцагчид' },
  { to: '/invoices', label: 'Нэхэмжлэх' },
  { to: '/fleet', label: 'Авто парк' },
  { to: '/drivers', label: 'Жолооч нар' },
  { to: '/lanes', label: 'Чиглэлүүд' },
  { to: '/data', label: 'Өгөгдөл' },
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
        <nav className="nav" aria-label="Үндсэн цэс">
          {NAV_ITEMS.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.to === '/'}>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-account">
          <NavLink to="/account" className="account-link" title="Бүртгэл ба хэрэглэгчид">
            <span className="avatar" aria-hidden="true">
              {username?.charAt(0).toUpperCase()}
            </span>
            <span className="account-name">{username}</span>
          </NavLink>
          <button type="button" className="button ghost small" onClick={() => void signOut()}>
            Гарах
          </button>
        </div>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  )
}
