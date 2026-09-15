const DASH = '—'

// NordFreight invoices in euros; the database stores amounts without a currency.
const moneyFormat = new Intl.NumberFormat('en-IE', { style: 'currency', currency: 'EUR' })
const preciseMoneyFormat = new Intl.NumberFormat('en-IE', {
  style: 'currency',
  currency: 'EUR',
  minimumFractionDigits: 3,
  maximumFractionDigits: 3,
})

type Maybe<T> = T | null | undefined

export function money(value: Maybe<number>): string {
  return value == null ? DASH : moneyFormat.format(value)
}

export function preciseMoney(value: Maybe<number>): string {
  return value == null ? DASH : preciseMoneyFormat.format(value)
}

/** Short amounts for tiles and axes, with Mongolian units: €137.6 мян., €1.2 сая. */
export function compactMoney(value: Maybe<number>): string {
  if (value == null) return DASH
  let scaled = value
  let unit = ''
  if (Math.abs(value) >= 1e6) {
    scaled = value / 1e6
    unit = ' сая'
  } else if (Math.abs(value) >= 1e3) {
    scaled = value / 1e3
    unit = ' мян.'
  }
  return `€${scaled.toLocaleString('en-IE', { maximumFractionDigits: 1 })}${unit}`
}

export function num(value: Maybe<number>, digits = 0): string {
  return value == null
    ? DASH
    : value.toLocaleString('en-IE', { minimumFractionDigits: digits, maximumFractionDigits: digits })
}

export function percent(value: Maybe<number>, digits = 1): string {
  return value == null ? DASH : `${value.toFixed(digits)}%`
}

/** Mongolian nouns stay singular after a number: "3 ачаа". */
export function count(value: number, noun: string): string {
  return `${num(value)} ${noun}`
}

/** The API sends dates as ISO strings and datetimes as UTC without an offset. */
function parse(value: string): Date {
  if (value.length <= 10) return new Date(`${value}T00:00:00Z`)
  return new Date(`${value.replace(/(\.\d{3})\d+/, '$1')}Z`)
}

const pad = (value: number) => String(value).padStart(2, '0')

// Dates are formatted by hand: browsers don't reliably ship Mongolian locale data for Intl.

/** 2026.09.15 */
export function date(value: Maybe<string>): string {
  if (!value) return DASH
  const parsed = parse(value)
  return `${parsed.getUTCFullYear()}.${pad(parsed.getUTCMonth() + 1)}.${pad(parsed.getUTCDate())}`
}

/** 2026.09.15 07:46 UTC */
export function dateTime(value: Maybe<string>): string {
  if (!value) return DASH
  const parsed = parse(value)
  return `${date(value)} ${pad(parsed.getUTCHours())}:${pad(parsed.getUTCMinutes())} UTC`
}

/** 2026 оны 9-р сар */
export function month(value: string): string {
  const parsed = parse(value)
  return `${parsed.getUTCFullYear()} оны ${parsed.getUTCMonth() + 1}-р сар`
}

/** 2026.09, short enough for a chart axis. */
export function monthTick(value: string): string {
  const parsed = parse(value)
  return `${parsed.getUTCFullYear()}.${pad(parsed.getUTCMonth() + 1)}`
}

export function todayUtc(): string {
  return new Date().toISOString().slice(0, 10)
}

/** For database values such as statuses, which stay in English: "OutForDelivery" → "Out for delivery". */
export function humanize(value: string): string {
  const spaced = value.replace(/([a-z])([A-Z])/g, '$1 $2')
  return spaced.charAt(0) + spaced.slice(1).toLowerCase()
}
