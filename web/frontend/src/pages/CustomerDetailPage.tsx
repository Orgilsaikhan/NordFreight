import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { Field, Fields } from '../components/Fields'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { Loadable } from '../components/States'
import { StatTile } from '../components/StatTile'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import { SHIPMENT_STATUSES } from '../status'
import type { CustomerDetail, CustomerInvoice, CustomerShipment, Page } from '../types'
import { useApi } from '../useApi'

const SHIPMENTS_PAGE_SIZE = 10

const shipmentColumns: Column<CustomerShipment>[] = [
  {
    key: 'tracking',
    header: 'Tracking',
    render: (shipment) => <Link to={`/shipments/${shipment.ShipmentId}`}>{shipment.TrackingNumber}</Link>,
  },
  { key: 'lane', header: 'Lane', render: (shipment) => `${shipment.OriginTerminal} → ${shipment.DestinationTerminal}` },
  { key: 'service', header: 'Service', render: (shipment) => shipment.ServiceCode },
  { key: 'pickup', header: 'Pickup', render: (shipment) => fmt.date(shipment.PickupDate) },
  { key: 'delivery', header: 'Delivery', render: (shipment) => <StatusBadge value={shipment.DeliveryPerformance} /> },
  { key: 'status', header: 'Status', render: (shipment) => <StatusBadge value={shipment.Status} /> },
  {
    key: 'billing',
    header: 'Billing',
    render: (shipment) => shipment.InvoiceNumber ?? fmt.humanize(shipment.BillingStatus),
  },
  { key: 'total', header: 'Total', align: 'right', render: (shipment) => fmt.money(shipment.TotalAmount) },
]

const invoiceColumns: Column<CustomerInvoice>[] = [
  {
    key: 'number',
    header: 'Invoice',
    render: (invoice) => <Link to={`/invoices/${invoice.InvoiceId}`}>{invoice.InvoiceNumber}</Link>,
  },
  { key: 'issued', header: 'Issued', render: (invoice) => fmt.date(invoice.IssueDate) },
  { key: 'due', header: 'Due', render: (invoice) => fmt.date(invoice.DueDate) },
  { key: 'status', header: 'Status', render: (invoice) => <StatusBadge value={invoice.Status} /> },
  { key: 'total', header: 'Total', align: 'right', render: (invoice) => fmt.money(invoice.TotalAmount) },
  { key: 'balance', header: 'Balance', align: 'right', render: (invoice) => fmt.money(invoice.BalanceDue) },
]

export function CustomerDetailPage() {
  const { id } = useParams()
  const state = useApi<CustomerDetail>(`/customers/${id}`)
  return <Loadable state={state}>{(customer) => <CustomerView customer={customer} />}</Loadable>
}

function CustomerView({ customer: c }: { customer: CustomerDetail }) {
  const navigate = useNavigate()
  const hasCreditLimit = c.CreditLimit > 0

  return (
    <>
      <PageHeader
        back={{ to: '/customers', label: 'Харилцагчид' }}
        title={c.LegalName}
        subtitle={[c.CustomerCode, c.TradingName].filter(Boolean).join(' · ')}
        actions={<StatusBadge value={c.IsActive ? 'Active' : 'Inactive'} />}
      />
      <div className="stack">
        <div className="kpis">
          <StatTile
            label="Нийт орлого"
            value={fmt.compactMoney(c.LifetimeRevenue)}
            meta={fmt.count(c.TotalShipments ?? 0, 'ачаа')}
          />
          <StatTile label="Идэвхтэй ачаа" value={fmt.num(c.OpenShipments)} meta={`Сүүлд ачсан: ${fmt.date(c.LastShipmentDate)}`} />
          <StatTile
            label="Хугацаандаа хүргэлт"
            value={fmt.percent(c.OnTimePercentage)}
            meta={`Хүргэсэн: ${fmt.num(c.DeliveredShipments)}`}
          />
          <StatTile
            label="Төлөгдөөгүй үлдэгдэл"
            value={fmt.compactMoney(c.OutstandingBalance)}
            meta={hasCreditLimit ? `Боломжит зээл: ${fmt.compactMoney(c.AvailableCredit)}` : 'Зээлийн хязгааргүй'}
          />
        </div>

        <div className="grid-2">
          <Card title="Харилцагчийн мэдээлэл">
            <Fields>
              <Field label="Татвар төлөгчийн дугаар">{c.TaxNumber}</Field>
              <Field label="Нэхэмжлэх хаяг">
                {`${c.BillingLine1}, ${c.BillingPostalCode} ${c.BillingCity}, ${c.BillingCountry}`}
              </Field>
              <Field label="Хамтарч эхэлсэн">{fmt.date(c.OnboardedOn)}</Field>
              <Field label="Төлбөрийн хугацаа">{fmt.count(c.PaymentTermsDays, 'хоног')}</Field>
              <Field label="Зээлийн хязгаар">{hasCreditLimit ? fmt.money(c.CreditLimit) : 'Хязгааргүй'}</Field>
              <Field label="Боломжит зээл">{hasCreditLimit ? fmt.money(c.AvailableCredit) : '—'}</Field>
            </Fields>
          </Card>
          <Card title="Холбоо барих хүмүүс">
            {c.contacts.length === 0 ? (
              <p className="empty">Холбоо барих хүн бүртгэгдээгүй.</p>
            ) : (
              <ul className="list">
                {c.contacts.map((contact) => (
                  <li key={contact.ContactId}>
                    <div>
                      <strong>{contact.FullName}</strong>
                      {contact.IsPrimary && <span className="tag">Үндсэн</span>}
                    </div>
                    <div className="muted small">
                      {contact.JobTitle && <span>{contact.JobTitle} · </span>}
                      <a href={`mailto:${contact.Email}`}>{contact.Email}</a>
                      {contact.Phone && <span> · {contact.Phone}</span>}
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <CustomerShipments customerId={c.CustomerId} />

        <Card title="Нэхэмжлэх">
          <DataTable
            columns={invoiceColumns}
            rows={c.invoices}
            rowKey={(invoice) => invoice.InvoiceId}
            onRowClick={(invoice) => navigate(`/invoices/${invoice.InvoiceId}`)}
            empty="Нэхэмжлэх алга."
          />
        </Card>
      </div>
    </>
  )
}

function CustomerShipments({ customerId }: { customerId: number }) {
  const navigate = useNavigate()
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState('')
  const query = new URLSearchParams({ page: String(page), page_size: String(SHIPMENTS_PAGE_SIZE) })
  if (status) query.set('status', status)
  const state = useApi<Page<CustomerShipment>>(`/customers/${customerId}/shipments?${query}`)

  return (
    <Card
      title="Ачаа"
      subtitle="usp_GetCustomerShipments хуудаслан гаргана"
      actions={
        <select
          className="select small"
          aria-label="Ачааг төлөвөөр шүүх"
          value={status}
          onChange={(event) => {
            setStatus(event.target.value)
            setPage(1)
          }}
        >
          <option value="">Бүх төлөв</option>
          {SHIPMENT_STATUSES.map((value) => (
            <option key={value} value={value}>
              {fmt.humanize(value)}
            </option>
          ))}
        </select>
      }
    >
      <Loadable state={state}>
        {(data) => (
          <>
            <DataTable
              columns={shipmentColumns}
              rows={data.rows}
              rowKey={(shipment) => shipment.ShipmentId}
              onRowClick={(shipment) => navigate(`/shipments/${shipment.ShipmentId}`)}
              empty="Тохирох ачаа алга."
            />
            <Pagination page={page} pageSize={SHIPMENTS_PAGE_SIZE} total={data.total} onPage={setPage} />
          </>
        )}
      </Loadable>
    </Card>
  )
}
