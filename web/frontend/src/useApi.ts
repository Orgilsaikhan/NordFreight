import { useCallback, useEffect, useState } from 'react'
import { api, errorText } from './api'

export interface ApiState<T> {
  data: T | null
  error: string | null
  loading: boolean
  reload: () => void
}

interface Settled<T> {
  key: string
  data: T | null
  error: string | null
}

/**
 * Fetches `path` and refetches whenever it changes. The previous data stays on screen
 * while a refetch runs, so the page keeps its layout instead of flashing a loader.
 */
export function useApi<T>(path: string): ApiState<T> {
  const [version, setVersion] = useState(0)
  const [settled, setSettled] = useState<Settled<T>>({ key: '', data: null, error: null })
  const key = `${version}:${path}`

  useEffect(() => {
    const controller = new AbortController()
    api.get<T>(path, controller.signal).then(
      (data) => {
        if (!controller.signal.aborted) setSettled({ key, data, error: null })
      },
      (err: unknown) => {
        if (!controller.signal.aborted) setSettled((previous) => ({ key, data: previous.data, error: errorText(err) }))
      },
    )
    return () => controller.abort()
  }, [key, path])

  const reload = useCallback(() => setVersion((current) => current + 1), [])
  const current = settled.key === key
  return { data: settled.data, error: current ? settled.error : null, loading: !current, reload }
}
