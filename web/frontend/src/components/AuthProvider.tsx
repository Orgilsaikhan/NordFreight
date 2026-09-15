import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { api, setUnauthorizedHandler } from '../api'
import { AuthContext, type AuthState } from '../auth'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthState['status']>('checking')
  const [username, setUsername] = useState<string | null>(null)
  const [signedOutByUser, setSignedOutByUser] = useState(false)

  useEffect(() => {
    let cancelled = false
    api.get<{ username: string }>('/auth/me').then(
      (me) => {
        if (cancelled) return
        setUsername(me.username)
        setStatus('signedIn')
      },
      () => {
        if (!cancelled) setStatus('signedOut')
      },
    )
    // A session that ends while the site is open sends the user back to the sign-in page.
    setUnauthorizedHandler(() => {
      setUsername(null)
      setStatus('signedOut')
    })
    return () => {
      cancelled = true
      setUnauthorizedHandler(null)
    }
  }, [])

  const signIn = useCallback(async (name: string, password: string) => {
    const me = await api.post<{ username: string }>('/auth/login', { username: name, password })
    setUsername(me.username)
    setSignedOutByUser(false)
    setStatus('signedIn')
  }, [])

  const signOut = useCallback(async () => {
    try {
      await api.post('/auth/logout', {})
    } finally {
      setUsername(null)
      setSignedOutByUser(true)
      setStatus('signedOut')
    }
  }, [])

  const value = useMemo<AuthState>(
    () => ({ status, username, signedOutByUser, signIn, signOut }),
    [status, username, signedOutByUser, signIn, signOut],
  )
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
