import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { useNavigate } from 'react-router'
import { api, errorText } from '../api'
import { Card } from '../components/Card'
import { Field, Fields } from '../components/Fields'
import { PageHeader } from '../components/PageHeader'
import { ErrorMessage, Loadable } from '../components/States'
import * as fmt from '../format'
import type { CreatedShipment, Lookups, Quote } from '../types'
import { useApi } from '../useApi'

const PACKAGING_TYPES = ['Pallet', 'Crate', 'Box', 'Drum', 'Bag', 'Roll']

type Address = Lookups['addresses'][number]
type CargoCategory = Lookups['cargo_categories'][number]
type QuoteState = 'idle' | 'loading' | 'ready' | 'none' | 'error'

const QUOTE_MESSAGES: Record<QuoteState, string> = {
  idle: 'Choose a lane, service, cargo category and item weights to see the price.',
  loading: 'Pricing…',
  ready: '',
  none: 'No rate is on file for this lane and service on the pickup date.',
  error: 'Could not price this shipment right now.',
}

interface ItemDraft {
  id: number
  description: string
  packaging: string
  quantity: string
  weight: string
  volume: string
}

let nextItemId = 1

function blankItem(): ItemDraft {
  return { id: nextItemId++, description: '', packaging: 'Pallet', quantity: '1', weight: '', volume: '' }
}

export function NewShipmentPage() {
  const lookups = useApi<Lookups>('/lookups')

  return (
    <>
      <PageHeader
        back={{ to: '/shipments', label: 'Shipments' }}
        title="New shipment"
        subtitle="Priced and credit-checked by usp_CreateShipment when you book"
      />
      <Loadable state={lookups}>{(data) => <ShipmentForm lookups={data} />}</Loadable>
    </>
  )
}

function ShipmentForm({ lookups }: { lookups: Lookups }) {
  const navigate = useNavigate()
  const today = fmt.todayUtc()
  const [customerId, setCustomerId] = useState('')
  const [laneId, setLaneId] = useState('')
  const [serviceLevelId, setServiceLevelId] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [pickupDate, setPickupDate] = useState(today)
  const [originId, setOriginId] = useState('')
  const [destinationId, setDestinationId] = useState('')
  const [declaredValue, setDeclaredValue] = useState('0')
  const [insured, setInsured] = useState(false)
  const [items, setItems] = useState<ItemDraft[]>(() => [blankItem()])
  const [quoteResult, setQuoteResult] = useState<{ key: string; quote: Quote | null; failed: boolean } | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const lane = lookups.lanes.find((candidate) => String(candidate.LaneId) === laneId)
  const category = lookups.cargo_categories.find((candidate) => String(candidate.CargoCategoryId) === categoryId)
  const totalWeight = items.reduce((sum, item) => sum + (Number(item.quantity) || 0) * (Number(item.weight) || 0), 0)
  const totalVolume = items.reduce((sum, item) => sum + (Number(item.quantity) || 0) * (Number(item.volume) || 0), 0)
  const weightKey = totalWeight.toFixed(2)

  const origins = useMemo(() => splitByCity(lookups.addresses, lane?.OriginCity), [lookups.addresses, lane?.OriginCity])
  const destinations = useMemo(
    () => splitByCity(lookups.addresses, lane?.DestinationCity),
    [lookups.addresses, lane?.DestinationCity],
  )

  // Everything that affects the price; null until there is enough to ask for one.
  const quoteKey =
    laneId && serviceLevelId && categoryId && Number(weightKey) > 0
      ? [laneId, serviceLevelId, categoryId, weightKey, pickupDate].join('|')
      : null

  // Re-price shortly after those inputs settle.
  useEffect(() => {
    if (quoteKey === null) return
    let cancelled = false
    const timer = setTimeout(() => {
      api
        .post<Quote | null>('/shipments/quote', {
          lane_id: Number(laneId),
          service_level_id: Number(serviceLevelId),
          cargo_category_id: Number(categoryId),
          weight_kg: weightKey,
          pickup_date: pickupDate || null,
        })
        .then(
          (quote) => {
            if (!cancelled) setQuoteResult({ key: quoteKey, quote, failed: false })
          },
          () => {
            if (!cancelled) setQuoteResult({ key: quoteKey, quote: null, failed: true })
          },
        )
    }, 300)
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [quoteKey, laneId, serviceLevelId, categoryId, weightKey, pickupDate])

  const quote = quoteResult?.quote ?? null
  const quoteState: QuoteState =
    quoteKey === null
      ? 'idle'
      : quoteResult === null || quoteResult.key !== quoteKey
        ? 'loading'
        : quoteResult.failed
          ? 'error'
          : quoteResult.quote
            ? 'ready'
            : 'none'

  function updateItem(id: number, changes: Partial<ItemDraft>) {
    setItems((current) => current.map((item) => (item.id === id ? { ...item, ...changes } : item)))
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSaving(true)
    setError(null)
    try {
      const created = await api.post<CreatedShipment>('/shipments', {
        customer_id: Number(customerId),
        lane_id: Number(laneId),
        service_level_id: Number(serviceLevelId),
        cargo_category_id: Number(categoryId),
        origin_address_id: Number(originId),
        destination_address_id: Number(destinationId),
        pickup_date: pickupDate || null,
        declared_value: declaredValue || '0',
        is_insured: insured,
        items: items.map((item) => ({
          description: item.description.trim(),
          packaging_type: item.packaging,
          quantity: Number(item.quantity),
          unit_weight_kg: item.weight,
          unit_volume_m3: item.volume,
        })),
      })
      navigate(`/shipments/${created.ShipmentId}`)
    } catch (err) {
      setError(errorText(err))
      setSaving(false)
    }
  }

  const showQuote = quote !== null && (quoteState === 'ready' || quoteState === 'loading')
  const hint = category ? categoryHint(category) : ''

  return (
    <form className="form-layout" onSubmit={submit}>
      <div className="stack">
        <Card title="Booking">
          <div className="form-grid">
            <label className="control">
              <span>Customer</span>
              <select className="select" required value={customerId} onChange={(event) => setCustomerId(event.target.value)}>
                <option value="">Choose a customer</option>
                {lookups.customers
                  .filter((customer) => customer.IsActive)
                  .map((customer) => (
                    <option key={customer.CustomerId} value={customer.CustomerId}>
                      {`${customer.LegalName} (${customer.CustomerCode})`}
                    </option>
                  ))}
              </select>
            </label>
            <label className="control">
              <span>Pickup date</span>
              <input
                className="input"
                type="date"
                required
                min={today}
                value={pickupDate}
                onChange={(event) => setPickupDate(event.target.value)}
              />
            </label>
            <label className="control">
              <span>Lane</span>
              <select className="select" required value={laneId} onChange={(event) => setLaneId(event.target.value)}>
                <option value="">Choose a lane</option>
                {lookups.lanes
                  .filter((candidate) => candidate.IsActive)
                  .map((candidate) => (
                    <option key={candidate.LaneId} value={candidate.LaneId}>
                      {`${candidate.OriginCity} → ${candidate.DestinationCity} (${fmt.num(candidate.DistanceKm)} km)`}
                    </option>
                  ))}
              </select>
            </label>
            <label className="control">
              <span>Service</span>
              <select
                className="select"
                required
                value={serviceLevelId}
                onChange={(event) => setServiceLevelId(event.target.value)}
              >
                <option value="">Choose a service</option>
                {lookups.service_levels.map((service) => (
                  <option key={service.ServiceLevelId} value={service.ServiceLevelId}>
                    {`${service.ServiceName} (up to ${fmt.plural(service.MaxTransitDays, 'day')})`}
                  </option>
                ))}
              </select>
            </label>
            <label className="control">
              <span>Cargo category</span>
              <select className="select" required value={categoryId} onChange={(event) => setCategoryId(event.target.value)}>
                <option value="">Choose a category</option>
                {lookups.cargo_categories.map((candidate) => (
                  <option key={candidate.CargoCategoryId} value={candidate.CargoCategoryId}>
                    {candidate.CategoryName}
                  </option>
                ))}
              </select>
              {hint && <span className="hint">{hint}</span>}
            </label>
            <label className="control">
              <span>Declared value (EUR)</span>
              <input
                className="input"
                type="number"
                min="0"
                step="0.01"
                max={category?.MaxDeclaredValue ?? undefined}
                value={declaredValue}
                onChange={(event) => setDeclaredValue(event.target.value)}
              />
            </label>
            <AddressSelect
              label="Collect from"
              value={originId}
              onChange={setOriginId}
              groups={origins}
              city={lane?.OriginCity}
            />
            <AddressSelect
              label="Deliver to"
              value={destinationId}
              onChange={setDestinationId}
              groups={destinations}
              city={lane?.DestinationCity}
            />
            <label className="checkbox wide">
              <input type="checkbox" checked={insured} onChange={(event) => setInsured(event.target.checked)} />
              Insure this shipment
            </label>
          </div>
        </Card>

        <Card
          title="Items"
          actions={
            <button type="button" className="button small" onClick={() => setItems((current) => [...current, blankItem()])}>
              Add item
            </button>
          }
        >
          <div className="table-wrap">
            <table className="table items-table">
              <thead>
                <tr>
                  <th scope="col">Description</th>
                  <th scope="col">Packaging</th>
                  <th scope="col" className="num">
                    Quantity
                  </th>
                  <th scope="col" className="num">
                    Unit weight (kg)
                  </th>
                  <th scope="col" className="num">
                    Unit volume (m³)
                  </th>
                  <th scope="col">
                    <span className="sr-only">Remove</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {items.map((item, index) => (
                  <tr key={item.id}>
                    <td>
                      <input
                        className="input"
                        required
                        maxLength={200}
                        aria-label={`Item ${index + 1} description`}
                        value={item.description}
                        onChange={(event) => updateItem(item.id, { description: event.target.value })}
                      />
                    </td>
                    <td>
                      <select
                        className="select"
                        aria-label={`Item ${index + 1} packaging`}
                        value={item.packaging}
                        onChange={(event) => updateItem(item.id, { packaging: event.target.value })}
                      >
                        {PACKAGING_TYPES.map((type) => (
                          <option key={type} value={type}>
                            {type}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <input
                        className="input num"
                        type="number"
                        required
                        min="1"
                        step="1"
                        aria-label={`Item ${index + 1} quantity`}
                        value={item.quantity}
                        onChange={(event) => updateItem(item.id, { quantity: event.target.value })}
                      />
                    </td>
                    <td>
                      <input
                        className="input num"
                        type="number"
                        required
                        min="0.001"
                        step="0.001"
                        aria-label={`Item ${index + 1} unit weight in kilograms`}
                        value={item.weight}
                        onChange={(event) => updateItem(item.id, { weight: event.target.value })}
                      />
                    </td>
                    <td>
                      <input
                        className="input num"
                        type="number"
                        required
                        min="0.0001"
                        step="0.0001"
                        aria-label={`Item ${index + 1} unit volume in cubic metres`}
                        value={item.volume}
                        onChange={(event) => updateItem(item.id, { volume: event.target.value })}
                      />
                    </td>
                    <td>
                      <button
                        type="button"
                        className="button ghost small"
                        disabled={items.length === 1}
                        onClick={() => setItems((current) => current.filter((other) => other.id !== item.id))}
                      >
                        Remove
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </div>

      <aside className="form-aside">
        <Card title="Price">
          <div className="stack">
            <Fields>
              <Field label="Total weight">{fmt.num(totalWeight, 2)} kg</Field>
              <Field label="Total volume">{fmt.num(totalVolume, 3)} m³</Field>
            </Fields>
            {showQuote && quote ? (
              <div className={quoteState === 'loading' ? 'refreshing' : undefined}>
                <Fields>
                  <Field label="Freight">{fmt.money(quote.FreightCharge)}</Field>
                  <Field label="Surcharges">{fmt.money(quote.SurchargeAmount)}</Field>
                  <Field label="VAT">{fmt.money(quote.TaxAmount)}</Field>
                  <Field label="Total">
                    <strong>{fmt.money(quote.TotalAmount)}</strong>
                  </Field>
                </Fields>
              </div>
            ) : (
              <p className="hint">{QUOTE_MESSAGES[quoteState]}</p>
            )}
            {error && <ErrorMessage message={error} />}
            <button type="submit" className="button primary block" disabled={saving}>
              {saving ? 'Booking…' : 'Book shipment'}
            </button>
          </div>
        </Card>
      </aside>
    </form>
  )
}

interface AddressGroups {
  nearby: Address[]
  others: Address[]
}

/** Puts addresses in the lane's city first, since those are the likely pickup and drop-off points. */
function splitByCity(addresses: Address[], city: string | undefined): AddressGroups {
  if (!city) return { nearby: [], others: addresses }
  return {
    nearby: addresses.filter((address) => address.CityName === city),
    others: addresses.filter((address) => address.CityName !== city),
  }
}

interface AddressSelectProps {
  label: string
  value: string
  onChange: (value: string) => void
  groups: AddressGroups
  city: string | undefined
}

function AddressSelect({ label, value, onChange, groups, city }: AddressSelectProps) {
  return (
    <label className="control">
      <span>{label}</span>
      <select className="select" required value={value} onChange={(event) => onChange(event.target.value)}>
        <option value="">Choose an address</option>
        {groups.nearby.length > 0 && <optgroup label={`In ${city}`}>{groups.nearby.map(addressOption)}</optgroup>}
        <optgroup label={groups.nearby.length > 0 ? 'Other cities' : 'All addresses'}>
          {groups.others.map(addressOption)}
        </optgroup>
      </select>
    </label>
  )
}

function addressOption(address: Address) {
  return (
    <option key={address.AddressId} value={address.AddressId}>
      {`${address.Line1}, ${address.PostalCode} ${address.CityName}`}
    </option>
  )
}

function categoryHint(category: CargoCategory): string {
  const notes: string[] = []
  if (category.RequiresHazmat) notes.push('Dangerous goods, needs an ADR-endorsed crew')
  if (category.RequiresRefrigeration) notes.push('Travels on refrigerated vehicles')
  if (category.MaxDeclaredValue != null) notes.push(`Declared value up to ${fmt.money(category.MaxDeclaredValue)}`)
  return notes.join(' · ')
}
