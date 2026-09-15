import type { useSearchParams } from 'react-router'

type SetSearchParams = ReturnType<typeof useSearchParams>[1]

/** Sets (or clears, for empty values) query-string keys without adding a history entry. */
export function updateSearchParams(setParams: SetSearchParams, changes: Record<string, string>) {
  setParams(
    (current) => {
      const next = new URLSearchParams(current)
      for (const [key, value] of Object.entries(changes)) {
        if (value) next.set(key, value)
        else next.delete(key)
      }
      return next
    },
    { replace: true },
  )
}
