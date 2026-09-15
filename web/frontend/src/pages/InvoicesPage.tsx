import { useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Loadable } from '../components/States'
import { StatTile } from '../components/StatTile'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import { updateSearchParams } from '../searchParams'
import { AGEING_BUCKETS, INVOICE_STATUSES } from '../status'
import type { InvoiceList, InvoiceRow } from '../types'
import { useApi } from '../useApi'

const columns: Column<InvoiceRow>[] = [
  {
    key: 'number',
    header: 'Invoice',
    render: (invoice) => <Link to={`/invoices/${invoice.InvoiceId}`}>{invoice.InvoiceNumber}</Link>,
    sortValue: (invoice) => invoice.InvoiceNumber,
  },
  { key: 'customer', header: 'Customer', render: (invoice) => invoice.CustomerName, sortValue: (invoice) => invoice.CustomerName },
  { key: 'issued', header: 'Issued', render: (invoice) => fmt.date(invoice.IssueDate), sortValue: (invoice) => invoice.IssueDate },
  { key: 'due', header: 'Due', render: (invoice) => fmt.date(invoice.DueDate), sortValue: (invoice) => invoice.DueDate },
  { key: 'status', header: 'Status', render: (invoice) => <StatusBadge value={invoice.Status} />, sortValue: (invoice) => invoice.Status },
  {
    key: 'total',
    header: 'Total',
    align: 'right',
    render: (invoice) => fmt.money(invoice.TotalAmount),
    sortValue: (invoice) => invoice.TotalAmount,
  },
  {
    key: 'paid',
    header: 'Paid',
    align: 'right',
    render: (invoice) => fmt.money(invoice.AmountPaid),
    sortValue: (invoice) => invoice.AmountPaid,
  },
  {
    key: 'balance',
    header: 'Balance',
    align: 'right',
    render: (invoice) => fmt.money(invoice.BalanceDue),
    sortValue: (invoice) => invoice.BalanceDue,
  },
  {
    key: 'overdue',
    header: 'Overdue',
    align: 'right',
    render: (invoice) => (invoice.DaysOverdue && invoice.DaysOverdue > 0 ? fmt.plural(invoice.DaysOverdue, 'day') : '—'),
    sortValue: (invoice) => (invoice.DaysOverdue && invoice.DaysOverdue > 0 ? invoice.DaysOverdue : null),
  },
]

export function InvoicesPage() {
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const scope = params.get('scope') === 'all' ? 'all' : 'outstanding'
  const status = scope === 'all' ? (params.get('status') ?? '') : ''
  const [search, setSearch] = useState('')

  const query = new URLSearchParams()
  if (scope === 'outstanding') query.set('outstanding', 'true')
  if (status) query.set('status', status)
  const state = useApi<InvoiceList>(`/invoices?${query}`)

  return (
    <>
      <PageHeader title="Invoices" subtitle="Receivables and payment status" />
      <Loadable state={state}>
        {(data) => {
          const term = search.trim().toLowerCase()
          const rows = term
            ? data.rows.filter((invoice) =>
                `${invoice.InvoiceNumber} ${invoice.CustomerName} ${invoice.CustomerCode}`.toLowerCase().includes(term),
              )
            : data.rows

          return (
            <div className="stack">
              <div className="kpis">
                {AGEING_BUCKETS.map((bucket) => {
                  const entry = data.ageing.find((candidate) => candidate.AgeingBucket === bucket)
                  return (
                    <StatTile
                      key={bucket}
                      label={bucket === 'Current' ? 'Not yet due' : `Overdue ${bucket}`}
                      value={fmt.compactMoney(entry?.BalanceDue ?? 0)}
                      meta={fmt.plural(entry?.Invoices ?? 0, 'invoice')}
                    />
                  )
                })}
              </div>

              <div className="toolbar">
                <div className="segmented" role="group" aria-label="Which invoices">
                  <button
                    type="button"
                    aria-pressed={scope === 'outstanding'}
                    onClick={() => updateSearchParams(setParams, { scope: '', status: '' })}
                  >
                    Outstanding
                  </button>
                  <button
                    type="button"
                    aria-pressed={scope === 'all'}
                    onClick={() => updateSearchParams(setParams, { scope: 'all' })}
                  >
                    All
                  </button>
                </div>
                {scope === 'all' && (
                  <select
                    className="select"
                    aria-label="Filter by status"
                    value={status}
                    onChange={(event) => updateSearchParams(setParams, { status: event.target.value })}
                  >
                    <option value="">All statuses</option>
                    {INVOICE_STATUSES.map((value) => (
                      <option key={value} value={value}>
                        {fmt.humanize(value)}
                      </option>
                    ))}
                  </select>
                )}
                <input
                  className="input search"
                  type="search"
                  placeholder="Search invoice or customer"
                  aria-label="Search invoices"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                />
              </div>

              <Card>
                <DataTable
                  columns={columns}
                  rows={rows}
                  rowKey={(invoice) => invoice.InvoiceId}
                  onRowClick={(invoice) => navigate(`/invoices/${invoice.InvoiceId}`)}
                  empty="No invoices match."
                />
              </Card>
            </div>
          )
        }}
      </Loadable>
    </>
  )
}
