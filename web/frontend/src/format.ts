const DASH = '—'

// NordFreight invoices in euros; the database stores amounts without a currency.
const moneyFormat = new Intl.NumberFormat('en-IE', { style: 'currency', currency: 'EUR' })
const preciseMoneyFormat = new Intl.NumberFormat('en-IE', {
  style: 'currency',
  currency: 'EUR',
  minimumFractionDigits: 3,
  maximumFractionDigits: 3,
})
const compactMoneyFormat = new Intl.NumberFormat('en-IE', {
  style: 'currency',
  currency: 'EUR',
  notation: 'compact',
  maximumFractionDigits: 1,
})
const dateFormat = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' })
const dateTimeFormat = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  timeZone: 'UTC',
})
const monthFormat = new Intl.DateTimeFormat('en-GB', { month: 'long', year: 'numeric', timeZone: 'UTC' })
const monthTickFormat = new Intl.DateTimeFormat('en-GB', { month: 'short', year: '2-digit', timeZone: 'UTC' })

type Maybe<T> = T | null | undefined

export function money(value: Maybe<number>): string {
  return value == null ? DASH : moneyFormat.format(value)
}

export function preciseMoney(value: Maybe<number>): string {
  return value == null ? DASH : preciseMoneyFormat.format(value)
}

export function compactMoney(value: Maybe<number>): string {
  return value == null ? DASH : compactMoneyFormat.format(value)
}

export function num(value: Maybe<number>, digits = 0): string {
  return value == null
    ? DASH
    : value.toLocaleString('en-IE', { minimumFractionDigits: digits, maximumFractionDigits: digits })
}

export function percent(value: Maybe<number>, digits = 1): string {
  return value == null ? DASH : `${value.toFixed(digits)}%`
}

export function plural(count: number, noun: string): string {
  return `${num(count)} ${noun}${count === 1 ? '' : 's'}`
}

/** The API sends dates as ISO strings and datetimes as UTC without an offset. */
function parse(value: string): Date {
  if (value.length <= 10) return new Date(`${value}T00:00:00Z`)
  return new Date(`${value.replace(/(\.\d{3})\d+/, '$1')}Z`)
}

export function date(value: Maybe<string>): string {
  return value ? dateFormat.format(parse(value)) : DASH
}

export function dateTime(value: Maybe<string>): string {
  return value ? `${dateTimeFormat.format(parse(value))} UTC` : DASH
}

export function month(value: string): string {
  return monthFormat.format(parse(value))
}

export function monthTick(value: string): string {
  return monthTickFormat.format(parse(value))
}

export function todayUtc(): string {
  return new Date().toISOString().slice(0, 10)
}

/** "OutForDelivery" → "Out for delivery", "On Time" → "On time". */
export function humanize(value: string): string {
  const spaced = value.replace(/([a-z])([A-Z])/g, '$1 $2')
  return spaced.charAt(0) + spaced.slice(1).toLowerCase()
}
