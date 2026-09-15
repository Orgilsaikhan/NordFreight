import { useState } from 'react'
import type { FormEvent } from 'react'
import { api, errorText } from '../api'
import { useAuth } from '../auth'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { ErrorMessage, Loadable } from '../components/States'
import * as fmt from '../format'
import { useApi } from '../useApi'

interface AppUser {
  id: number
  username: string
  created_at: string
}

const userColumns: Column<AppUser>[] = [
  { key: 'username', header: 'Username', render: (user) => user.username },
  { key: 'added', header: 'Added', render: (user) => fmt.dateTime(user.created_at) },
]

export function AccountPage() {
  const { username } = useAuth()

  return (
    <>
      <PageHeader title="Account" subtitle={`Signed in as ${username}`} />
      <div className="grid-2">
        <PasswordCard />
        <UsersCard />
      </div>
    </>
  )
}

function PasswordCard() {
  const [current, setCurrent] = useState('')
  const [next, setNext] = useState('')
  const [confirm, setConfirm] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [changed, setChanged] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setChanged(false)
    if (next !== confirm) {
      setError('The new passwords do not match.')
      return
    }
    setSaving(true)
    try {
      await api.post('/auth/password', { current_password: current, new_password: next })
      setCurrent('')
      setNext('')
      setConfirm('')
      setChanged(true)
    } catch (err) {
      setError(errorText(err))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Card title="Change password" subtitle="Other browsers signed in to this account will be signed out">
      <form className="stack" onSubmit={submit}>
        {error && <ErrorMessage message={error} />}
        {changed && (
          <p className="notice" role="status">
            Password changed.
          </p>
        )}
        <label className="control">
          <span>Current password</span>
          <input
            className="input"
            type="password"
            autoComplete="current-password"
            required
            value={current}
            onChange={(event) => setCurrent(event.target.value)}
          />
        </label>
        <label className="control">
          <span>New password</span>
          <input
            className="input"
            type="password"
            autoComplete="new-password"
            required
            minLength={8}
            value={next}
            onChange={(event) => setNext(event.target.value)}
          />
          <span className="hint">At least 8 characters.</span>
        </label>
        <label className="control">
          <span>Confirm new password</span>
          <input
            className="input"
            type="password"
            autoComplete="new-password"
            required
            minLength={8}
            value={confirm}
            onChange={(event) => setConfirm(event.target.value)}
          />
        </label>
        <div>
          <button type="submit" className="button primary" disabled={saving}>
            {saving ? 'Saving…' : 'Change password'}
          </button>
        </div>
      </form>
    </Card>
  )
}

function UsersCard() {
  const users = useApi<AppUser[]>('/users')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [added, setAdded] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSaving(true)
    setError(null)
    setAdded(null)
    try {
      const created = await api.post<AppUser>('/users', { username: username.trim(), password })
      setUsername('')
      setPassword('')
      setAdded(created.username)
      users.reload()
    } catch (err) {
      setError(errorText(err))
    } finally {
      setSaving(false)
    }
  }

  return (
    <Card title="Users" subtitle="Everyone signed in can view and change freight data">
      <div className="stack">
        <Loadable state={users}>
          {(rows) => <DataTable columns={userColumns} rows={rows} rowKey={(user) => user.id} />}
        </Loadable>
        <form className="form-inline" onSubmit={submit}>
          <label className="control">
            <span>New username</span>
            <input
              className="input"
              autoComplete="off"
              required
              minLength={3}
              maxLength={64}
              pattern="[A-Za-z0-9._\-]+"
              title="Letters, numbers, dots, dashes and underscores"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
            />
          </label>
          <label className="control">
            <span>Password</span>
            <input
              className="input"
              type="password"
              autoComplete="new-password"
              required
              minLength={8}
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
          </label>
          <button type="submit" className="button" disabled={saving}>
            {saving ? 'Adding…' : 'Add user'}
          </button>
        </form>
        {error && <ErrorMessage message={error} />}
        {added && (
          <p className="notice" role="status">
            {`Added ${added}. They can sign in now.`}
          </p>
        )}
      </div>
    </Card>
  )
}
