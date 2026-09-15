export class ApiError extends Error {
  readonly status: number

  constructor(status: number, message: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

interface ValidationIssue {
  loc?: (string | number)[]
}

let onUnauthorized: (() => void) | null = null

/** Registers what happens when a data request comes back 401, such as an expired session. */
export function setUnauthorizedHandler(handler: (() => void) | null) {
  onUnauthorized = handler
}

/** FastAPI sends `detail` as a string, or as a list of validation issues. */
function detailText(body: unknown): string | null {
  if (!body || typeof body !== 'object' || !('detail' in body)) return null
  const { detail } = body as { detail: unknown }
  if (typeof detail === 'string') return detail
  if (Array.isArray(detail)) {
    return detail
      .map((issue: ValidationIssue) => {
        const field = (issue.loc ?? []).filter((part) => part !== 'body').join('.')
        return field ? `Буруу утга: ${field}` : 'Хүсэлт буруу байна.'
      })
      .join('; ')
  }
  return null
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`/api${path}`, {
    ...init,
    headers: init.body ? { Accept: 'application/json', 'Content-Type': 'application/json' } : { Accept: 'application/json' },
  })
  const isJson = response.headers.get('content-type')?.includes('application/json') ?? false
  // 204 responses (sign out, password change) have no body to parse.
  const text = await response.text()
  const body: unknown = isJson && text ? JSON.parse(text) : null
  if (!response.ok) {
    // The sign-in endpoints report their own 401s; anywhere else it means the session is gone.
    if (response.status === 401 && !path.startsWith('/auth/')) onUnauthorized?.()
    if (!isJson && response.status >= 500) {
      throw new ApiError(response.status, 'API хариу өгөхгүй байна. Backend ажиллаж байгаа эсэхийг шалгана уу.')
    }
    throw new ApiError(response.status, detailText(body) ?? `Хүсэлт амжилтгүй боллоо (${response.status}).`)
  }
  return body as T
}

export const api = {
  get: <T>(path: string, signal?: AbortSignal) => request<T>(path, { signal }),
  post: <T>(path: string, data: unknown) => request<T>(path, { method: 'POST', body: JSON.stringify(data) }),
  patch: <T>(path: string, data: unknown) => request<T>(path, { method: 'PATCH', body: JSON.stringify(data) }),
}

export function errorText(error: unknown): string {
  if (error instanceof TypeError) return 'API-тай холбогдож чадсангүй. Backend ажиллаж байгаа эсэхийг шалгана уу.'
  if (error instanceof Error) return error.message
  return 'Алдаа гарлаа.'
}
