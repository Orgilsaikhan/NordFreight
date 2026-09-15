import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Navigate, useSearchParams } from 'react-router'
import { errorText } from '../api'
import { useAuth } from '../auth'
import { ErrorMessage } from '../components/States'

/** Accepts only paths on this site, so the sign-in page can't forward people elsewhere. */
function safeNext(value: string | null): string {
  if (!value || !value.startsWith('/') || value.startsWith('//') || value.startsWith('/login')) return '/'
  return value
}

export function LoginPage() {
  const { status, signIn } = useAuth()
  const [params] = useSearchParams()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    document.title = 'Sign in · NordFreight'
  }, [])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitting(true)
    setError(null)
    try {
      await signIn(username.trim(), password)
    } catch (err) {
      setError(errorText(err))
      setPassword('')
      setSubmitting(false)
    }
  }

  if (status === 'checking') return null
  if (status === 'signedIn') return <Navigate to={safeNext(params.get('next'))} replace />

  return (
    <main className="login">
      <div className="login-panel">
        <div className="brand login-brand">
          <span className="brand-mark" aria-hidden="true" />
          NordFreight
        </div>
        <h1>Sign in</h1>
        <p className="subtitle">Use your NordFreight account to continue.</p>
        <form className="login-form" onSubmit={submit}>
          {error && <ErrorMessage message={error} />}
          <label className="control">
            <span>Username</span>
            <input
              className="input"
              name="username"
              autoComplete="username"
              autoFocus
              required
              value={username}
              onChange={(event) => setUsername(event.target.value)}
            />
          </label>
          <label className="control">
            <span>Password</span>
            <input
              className="input"
              type="password"
              name="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
          </label>
          <button type="submit" className="button primary block" disabled={submitting}>
            {submitting ? 'Signing in…' : 'Sign in'}
          </button>
        </form>
      </div>
    </main>
  )
}
