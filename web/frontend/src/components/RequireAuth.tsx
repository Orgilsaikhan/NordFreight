import { Navigate, Outlet, useLocation } from 'react-router'
import { useAuth } from '../auth'

/** Layout route that renders its child routes only for a signed-in user. */
export function RequireAuth() {
  const { status, signedOutByUser } = useAuth()
  const location = useLocation()

  if (status === 'checking') return null
  if (status === 'signedOut') {
    // Remember where the visitor was heading, except after a deliberate sign-out:
    // the next person to sign in shouldn't land on the previous person's page.
    const next = location.pathname + location.search
    const target = signedOutByUser || next === '/' ? '/login' : `/login?next=${encodeURIComponent(next)}`
    return <Navigate to={target} replace />
  }
  return <Outlet />
}
