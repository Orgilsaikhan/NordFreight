import type { ReactNode } from 'react'
import type { ApiState } from '../useApi'

export function Loading() {
  return <p className="state">Loading…</p>
}

export function ErrorMessage({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="alert" role="alert">
      <span>{message}</span>
      {onRetry && (
        <button type="button" className="button small" onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  )
}

/** Shows loading and error states, then renders the content once data has arrived. */
export function Loadable<T>({ state, children }: { state: ApiState<T>; children: (data: T) => ReactNode }) {
  if (state.data === null) {
    return state.error ? <ErrorMessage message={state.error} onRetry={state.reload} /> : <Loading />
  }
  return (
    <div className={state.loading ? 'refreshing' : undefined}>
      {state.error && <ErrorMessage message={state.error} onRetry={state.reload} />}
      {children(state.data)}
    </div>
  )
}
