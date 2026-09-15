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
      <PageHeader title="Бүртгэл" subtitle={`Нэвтэрсэн хэрэглэгч: ${username}`} />
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
      setError('Шинэ нууц үг таарахгүй байна.')
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
    <Card title="Нууц үг солих" subtitle="Энэ бүртгэлээр нэвтэрсэн бусад хөтчөөс гаргана">
      <form className="stack" onSubmit={submit}>
        {error && <ErrorMessage message={error} />}
        {changed && (
          <p className="notice" role="status">
            Нууц үг солигдлоо.
          </p>
        )}
        <label className="control">
          <span>Одоогийн нууц үг</span>
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
          <span>Шинэ нууц үг</span>
          <input
            className="input"
            type="password"
            autoComplete="new-password"
            required
            minLength={8}
            value={next}
            onChange={(event) => setNext(event.target.value)}
          />
          <span className="hint">Хамгийн багадаа 8 тэмдэгт.</span>
        </label>
        <label className="control">
          <span>Шинэ нууц үгээ давтах</span>
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
            {saving ? 'Хадгалж байна…' : 'Нууц үг солих'}
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
    <Card title="Хэрэглэгчид" subtitle="Нэвтэрсэн хэн бүхэн тээврийн мэдээллийг харж, өөрчилж чадна">
      <div className="stack">
        <Loadable state={users}>
          {(rows) => <DataTable columns={userColumns} rows={rows} rowKey={(user) => user.id} />}
        </Loadable>
        <form className="form-inline" onSubmit={submit}>
          <label className="control">
            <span>Шинэ нэвтрэх нэр</span>
            <input
              className="input"
              autoComplete="off"
              required
              minLength={3}
              maxLength={64}
              pattern="[A-Za-z0-9._\-]+"
              title="Латин үсэг, тоо, цэг, зураас, доогуур зураас"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
            />
          </label>
          <label className="control">
            <span>Нууц үг</span>
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
            {saving ? 'Нэмж байна…' : 'Хэрэглэгч нэмэх'}
          </button>
        </form>
        {error && <ErrorMessage message={error} />}
        {added && (
          <p className="notice" role="status">
            {`${added} нэмэгдлээ. Одоо нэвтэрч болно.`}
          </p>
        )}
      </div>
    </Card>
  )
}
