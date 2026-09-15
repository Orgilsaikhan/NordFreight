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
        back={{ to: '/invoices', label: 'Нэхэмжлэх' }}
        title={i.InvoiceNumber}
        subtitle={<Link to={`/customers/${i.CustomerId}`}>{i.CustomerName}</Link>}
        actions={
          <>
            <StatusBadge value={i.Status} />
            <Link className="button small" to={`/data/Invoices/row?InvoiceId=${i.InvoiceId}`}>
              Засах
            </Link>
          </>
        }
      />
      <div className="stack">
        <div className="kpis">
          <StatTile label="Нийт дүн" value={fmt.money(i.TotalAmount)} meta={`НӨАТ ${fmt.money(i.TaxAmount)} орсон`} />
          <StatTile label="Төлсөн" value={fmt.money(i.AmountPaid)} meta={fmt.count(i.payments.length, 'төлбөр')} />
          <StatTile
            label="Төлөх үлдэгдэл"
            value={fmt.money(i.BalanceDue)}
            meta={overdue ? `${fmt.count(i.DaysOverdue ?? 0, 'хоног')} хэтэрсэн` : `Төлөх хугацаа: ${fmt.date(i.DueDate)}`}
            trend={overdue ? 'bad' : undefined}
          />
          <StatTile label="Нэхэмжилсэн" value={fmt.date(i.IssueDate)} meta={`Төлөх хугацаа: ${fmt.date(i.DueDate)}`} />
        </div>

        {canPay && <PaymentForm key={i.AmountPaid} invoice={i} onChanged={onChanged} />}

        <Card title="Нэхэмжлэхийн мөр" subtitle={fmt.count(i.lines.length, 'ачаа')}>
          <DataTable columns={lineColumns} rows={i.lines} rowKey={(line) => line.LineNumber} />
        </Card>

        <Card title="Төлбөрүүд">
          <DataTable
            columns={paymentColumns}
            rows={i.payments}
            rowKey={(payment) => payment.PaymentId}
            empty="Төлбөр бүртгэгдээгүй байна."
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
    <Card title="Төлбөр бүртгэх" subtitle="usp_RecordPayment бүртгэнэ; нэхэмжлэхийн төлөв автоматаар шинэчлэгдэнэ">
      {error && <ErrorMessage message={error} />}
      <form className="form-inline" onSubmit={submit}>
        <label className="control">
          <span>Төлбөрийн хэлбэр</span>
          <select className="select" required value={selectedMethod} onChange={(event) => setMethodId(event.target.value)}>
            {methods.map((method) => (
              <option key={method.PaymentMethodId} value={method.PaymentMethodId}>
                {method.MethodName}
              </option>
            ))}
          </select>
        </label>
        <label className="control">
          <span>Дүн (EUR)</span>
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
          <span>Гүйлгээний дугаар</span>
          <input
            className="input"
            required
            maxLength={50}
            placeholder="Банкны гүйлгээний дугаар"
            value={reference}
            onChange={(event) => setReference(event.target.value)}
          />
        </label>
        <label className="control">
          <span>Төлсөн өдөр</span>
          <input className="input" type="date" required value={paidOn} onChange={(event) => setPaidOn(event.target.value)} />
        </label>
        <button type="submit" className="button primary" disabled={saving || methods.length === 0}>
          {saving ? 'Хадгалж байна…' : 'Төлбөр бүртгэх'}
        </button>
      </form>
    </Card>
  )
}
