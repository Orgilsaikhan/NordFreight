import { useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useParams } from 'react-router'
import { api, errorText } from '../api'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { Field, Fields } from '../components/Fields'
import { PageHeader } from '../components/PageHeader'
import { ErrorMessage, Loadable } from '../components/States'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import type { Lookups, ShipmentDetail, ShipmentItem, ShipmentTrip } from '../types'
import { useApi } from '../useApi'

const itemColumns: Column<ShipmentItem>[] = [
  { key: 'line', header: '#', render: (item) => item.LineNumber },
  { key: 'description', header: 'Description', render: (item) => item.Description },
  { key: 'packaging', header: 'Packaging', render: (item) => item.PackagingType },
  { key: 'quantity', header: 'Quantity', align: 'right', render: (item) => fmt.num(item.Quantity) },
  { key: 'weight', header: 'Weight', align: 'right', render: (item) => `${fmt.num(item.LineWeightKg, 2)} kg` },
  { key: 'volume', header: 'Volume', align: 'right', render: (item) => `${fmt.num(item.LineVolumeM3, 3)} m³` },
]

const tripColumns: Column<ShipmentTrip>[] = [
  { key: 'trip', header: 'Trip', render: (trip) => trip.TripNumber },
  { key: 'leg', header: 'Leg', render: (trip) => fmt.humanize(trip.LegType) },
  { key: 'route', header: 'Route', render: (trip) => `${trip.OriginTerminal} → ${trip.DestinationTerminal}` },
  { key: 'vehicle', header: 'Vehicle', render: (trip) => trip.PlateNumber },
  { key: 'crew', header: 'Crew', render: (trip) => trip.Crew ?? '—' },
  { key: 'departed', header: 'Departed', render: (trip) => fmt.dateTime(trip.ActualDeparture ?? trip.ScheduledDeparture) },
  { key: 'status', header: 'Status', render: (trip) => <StatusBadge value={trip.Status} /> },
]

export function ShipmentDetailPage() {
  const { id } = useParams()
  const state = useApi<ShipmentDetail>(`/shipments/${id}`)
  return <Loadable state={state}>{(shipment) => <ShipmentView shipment={shipment} onChanged={state.reload} />}</Loadable>
}

function ShipmentView({ shipment: s, onChanged }: { shipment: ShipmentDetail; onChanged: () => void }) {
  return (
    <>
      <PageHeader
        back={{ to: '/shipments', label: 'Shipments' }}
        title={s.TrackingNumber}
        subtitle={`${s.CustomerName} · ${s.OriginCity} → ${s.DestinationCity}`}
        actions={<StatusBadge value={s.Status} />}
      />
      <div className="stack">
        <div className="grid-2">
          <Card title="Shipment">
            <Fields>
              <Field label="Customer">
                <Link to={`/customers/${s.CustomerId}`}>{s.CustomerName}</Link>
              </Field>
              <Field label="Lane">
                {s.OriginTerminal} → {s.DestinationTerminal} · {fmt.num(s.DistanceKm)} km
              </Field>
              <Field label="Service">{s.ServiceName}</Field>
              <Field label="Cargo">{s.CategoryName}</Field>
              <Field label="Collect from">{s.OriginAddress}</Field>
              <Field label="Deliver to">{s.DestinationAddress}</Field>
              <Field label="Weight">{fmt.num(s.TotalWeightKg, 2)} kg</Field>
              <Field label="Volume">{fmt.num(s.TotalVolumeM3, 3)} m³</Field>
              <Field label="Declared value">
                {fmt.money(s.DeclaredValue)}
                {s.IsInsured ? ' · insured' : ''}
              </Field>
              <Field label="Booked">{fmt.dateTime(s.BookedAt)}</Field>
            </Fields>
          </Card>
          <div className="stack">
            <Card title="Delivery">
              <Fields>
                <Field label="Pickup">{fmt.date(s.PickupDate)}</Field>
                <Field label="Promised">{fmt.date(s.PromisedDeliveryDate)}</Field>
                <Field label="Delivered">{fmt.date(s.ActualDeliveryDate)}</Field>
                <Field label="Performance">
                  <StatusBadge value={s.DeliveryPerformance} />
                  {s.DaysLate ? <span className="muted"> · {fmt.plural(s.DaysLate, 'day')} late</span> : null}
                </Field>
              </Fields>
            </Card>
            <Card title="Charges">
              <Fields>
                <Field label="Freight">{fmt.money(s.FreightCharge)}</Field>
                <Field label="Surcharges">{fmt.money(s.SurchargeAmount)}</Field>
                <Field label="VAT">{fmt.money(s.TaxAmount)}</Field>
                <Field label="Total">
                  <strong>{fmt.money(s.TotalAmount)}</strong>
                </Field>
                <Field label="Billing">
                  {s.InvoiceId ? (
                    <Link to={`/invoices/${s.InvoiceId}`}>{s.InvoiceNumber}</Link>
                  ) : (
                    fmt.humanize(s.BillingStatus)
                  )}
                </Field>
              </Fields>
            </Card>
          </div>
        </div>

        {s.next_statuses.length > 0 && <StatusForm key={s.Status} shipment={s} onChanged={onChanged} />}

        <Card title="Items">
          <DataTable columns={itemColumns} rows={s.items} rowKey={(item) => item.LineNumber} />
        </Card>

        <div className="grid-2">
          <Card title="Status history">
            <ul className="list">
              {s.history.map((entry) => (
                <li key={entry.StatusHistoryId}>
                  <div className="row-between">
                    <StatusBadge value={entry.NewStatus} />
                    <span className="muted small">{fmt.dateTime(entry.ChangedAt)}</span>
                  </div>
                  <div className="muted small">
                    {[entry.OldStatus ? `From ${fmt.humanize(entry.OldStatus)}` : 'Booked', entry.TerminalCode, entry.ChangedBy]
                      .filter(Boolean)
                      .join(' · ')}
                  </div>
                  {entry.Notes && <div className="small">{entry.Notes}</div>}
                </li>
              ))}
            </ul>
          </Card>
          <Card title="Trips">
            <DataTable
              columns={tripColumns}
              rows={s.trips}
              rowKey={(trip) => trip.TripId}
              empty="Not assigned to a trip yet."
            />
          </Card>
        </div>
      </div>
    </>
  )
}

function StatusForm({ shipment, onChanged }: { shipment: ShipmentDetail; onChanged: () => void }) {
  const lookups = useApi<Lookups>('/lookups')
  const [status, setStatus] = useState(shipment.next_statuses[0])
  const [terminalId, setTerminalId] = useState('')
  const [deliveryDate, setDeliveryDate] = useState(fmt.todayUtc())
  const [notes, setNotes] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSaving(true)
    setError(null)
    try {
      await api.post(`/shipments/${shipment.ShipmentId}/status`, {
        status,
        terminal_id: terminalId ? Number(terminalId) : null,
        delivery_date: status === 'Delivered' ? deliveryDate : null,
        notes: notes.trim() || null,
      })
      onChanged()
    } catch (err) {
      setError(errorText(err))
      setSaving(false)
    }
  }

  return (
    <Card title="Update status" subtitle="Checked against the allowed transitions by usp_UpdateShipmentStatus">
      {error && <ErrorMessage message={error} />}
      <form className="form-inline" onSubmit={submit}>
        <label className="control">
          <span>New status</span>
          <select className="select" value={status} onChange={(event) => setStatus(event.target.value)}>
            {shipment.next_statuses.map((value) => (
              <option key={value} value={value}>
                {fmt.humanize(value)}
              </option>
            ))}
          </select>
        </label>
        <label className="control">
          <span>Terminal</span>
          <select className="select" value={terminalId} onChange={(event) => setTerminalId(event.target.value)}>
            <option value="">Not recorded</option>
            {lookups.data?.terminals.map((terminal) => (
              <option key={terminal.TerminalId} value={terminal.TerminalId}>
                {`${terminal.TerminalCode} · ${terminal.TerminalName}`}
              </option>
            ))}
          </select>
        </label>
        {status === 'Delivered' && (
          <label className="control">
            <span>Delivered on</span>
            <input
              className="input"
              type="date"
              required
              min={shipment.PickupDate.slice(0, 10)}
              value={deliveryDate}
              onChange={(event) => setDeliveryDate(event.target.value)}
            />
          </label>
        )}
        <label className="control grow">
          <span>Note</span>
          <input
            className="input"
            maxLength={400}
            placeholder="Optional"
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
          />
        </label>
        <button type="submit" className="button primary" disabled={saving}>
          {saving ? 'Saving…' : 'Update status'}
        </button>
      </form>
    </Card>
  )
}
