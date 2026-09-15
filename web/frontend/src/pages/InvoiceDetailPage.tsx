import { useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useParams } from 'react-router'
import { api, errorText } from '../api'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { ErrorMessage, Loadable } from '../components/States'
import { StatTile } from '../components/StatTile'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import type { InvoiceDetail, InvoiceLine, Lookups, Payment } from '../types'
import { useApi } from '../useApi'

const PAYABLE_STATUSES = ['Issued', 'PartiallyPaid', 'Overdue']

const lineColumns: Column<InvoiceLine>[] = [
  { key: 'line', header: '#', render: (line) => line.LineNumber },
  {
    key: 'shipment',
    header: 'Shipment',
    render: (line) => <Link to={`/shipments/${line.ShipmentId}`}>{line.TrackingNumber}</Link>,
  },
  { key: 'description', header: 'Description', render: (line) => line.Description },
  { key: 'net', header: 'Net', align: 'right', render: (line) => fmt.money(line.NetAmount) },
  { key: 'rate', header: 'VAT rate', align: 'right', render: (line) => fmt.percent(line.TaxRate * 100, 0) },
  { key: 'vat', header: 'VAT', align: 'right', render: (line) => fmt.money(line.TaxAmount) },
  { key: 'total', header: 'Total', align: 'right', render: (line) => fmt.money(line.LineTotal) },
]

const paymentColumns: Column<Payment>[] = [
  { key: 'paidOn', header: 'Paid on', render: (payment) => fmt.date(payment.PaidOn) },
  { key: 'method', header: 'Method', render: (payment) => payment.MethodName },
  { key: 'reference', header: 'Reference', render: (payment) => payment.ReferenceNumber },
  { key: 'amount', header: 'Amount', align: 'right', render: (payment) => fmt.money(payment.Amount) },
]

export function InvoiceDetailPage() {
  const { id } = useParams()
  const state = useApi<InvoiceDetail>(`/invoices/${id}`)
  return <Loadable state={state}>{(invoice) => <InvoiceView invoice={invoice} onChanged={state.reload} />}</Loadable>
}

function InvoiceView({ invoice: i, onChanged }: { invoice: InvoiceDetail; onChanged: () => void }) {
  const overdue = i.DaysOverdue !== null && i.DaysOverdue > 0 && i.BalanceDue > 0
  const canPay = PAYABLE_STATUSES.includes(i.Status) && i.BalanceDue > 0

  return (
    <>
      <PageHeader
        back={{ to: '/invoices', label: 'Invoices' }}
        title={i.InvoiceNumber}
        subtitle={<Link to={`/customers/${i.CustomerId}`}>{i.CustomerName}</Link>}
        actions={<StatusBadge value={i.Status} />}
      />
      <div className="stack">
        <div className="kpis">
          <StatTile label="Total" value={fmt.money(i.TotalAmount)} meta={`${fmt.money(i.TaxAmount)} VAT included`} />
          <StatTile label="Paid" value={fmt.money(i.AmountPaid)} meta={fmt.plural(i.payments.length, 'payment')} />
          <StatTile
            label="Balance due"
            value={fmt.money(i.BalanceDue)}
            meta={overdue ? `${fmt.plural(i.DaysOverdue ?? 0, 'day')} overdue` : `Due ${fmt.date(i.DueDate)}`}
            trend={overdue ? 'bad' : undefined}
          />
          <StatTile label="Issued" value={fmt.date(i.IssueDate)} meta={`Due ${fmt.date(i.DueDate)}`} />
        </div>

        {canPay && <PaymentForm key={i.AmountPaid} invoice={i} onChanged={onChanged} />}

        <Card title="Lines" subtitle={fmt.plural(i.lines.length, 'shipment')}>
          <DataTable columns={lineColumns} rows={i.lines} rowKey={(line) => line.LineNumber} />
        </Card>

        <Card title="Payments">
          <DataTable
            columns={paymentColumns}
            rows={i.payments}
            rowKey={(payment) => payment.PaymentId}
            empty="No payments recorded yet."
          />
        </Card>
      </div>
    </>
  )
}

function PaymentForm({ invoice, onChanged }: { invoice: InvoiceDetail; onChanged: () => void }) {
  const lookups = useApi<Lookups>('/lookups')
  const [methodId, setMethodId] = useState('')
  const [amount, setAmount] = useState(invoice.BalanceDue.toFixed(2))
  const [reference, setReference] = useState('')
  const [paidOn, setPaidOn] = useState(fmt.todayUtc())
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const methods = lookups.data?.payment_methods ?? []
  const selectedMethod = methodId || String(methods[0]?.PaymentMethodId ?? '')

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSaving(true)
    setError(null)
    try {
      await api.post(`/invoices/${invoice.InvoiceId}/payments`, {
        payment_method_id: Number(selectedMethod),
        amount,
        reference_number: reference.trim(),
        paid_on: paidOn || null,
      })
      onChanged()
    } catch (err) {
      setError(errorText(err))
      setSaving(false)
    }
  }

  return (
    <Card title="Record a payment" subtitle="Posted by usp_RecordPayment; the invoice status updates itself">
      {error && <ErrorMessage message={error} />}
      <form className="form-inline" onSubmit={submit}>
        <label className="control">
          <span>Method</span>
          <select className="select" required value={selectedMethod} onChange={(event) => setMethodId(event.target.value)}>
            {methods.map((method) => (
              <option key={method.PaymentMethodId} value={method.PaymentMethodId}>
                {method.MethodName}
              </option>
            ))}
          </select>
        </label>
        <label className="control">
          <span>Amount (EUR)</span>
          <input
            className="input"
            type="number"
            required
            min="0.01"
            max={invoice.BalanceDue}
            step="0.01"
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
          />
        </label>
        <label className="control grow">
          <span>Reference</span>
          <input
            className="input"
            required
            maxLength={50}
            placeholder="Bank reference"
            value={reference}
            onChange={(event) => setReference(event.target.value)}
          />
        </label>
        <label className="control">
          <span>Paid on</span>
          <input className="input" type="date" required value={paidOn} onChange={(event) => setPaidOn(event.target.value)} />
        </label>
        <button type="submit" className="button primary" disabled={saving || methods.length === 0}>
          {saving ? 'Saving…' : 'Record payment'}
        </button>
      </form>
    </Card>
  )
}
