import { createContext, useContext } from 'react'

export interface AuthState {
  /** `checking` until the first session lookup finishes. */
  status: 'checking' | 'signedOut' | 'signedIn'
  username: string | null
  /** True after the user chose to sign out, as opposed to arriving signed out or the session expiring. */
  signedOutByUser: boolean
  signIn: (username: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

export const AuthContext = createContext<AuthState | null>(null)

export function useAuth(): AuthState {
  const auth = useContext(AuthContext)
  if (!auth) throw new Error('useAuth must be used inside <AuthProvider>.')
  return auth
}
