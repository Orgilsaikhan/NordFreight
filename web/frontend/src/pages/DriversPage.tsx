import { useState } from 'react'
import { useNavigate } from 'react-router'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Loadable } from '../components/States'
import { StatusBadge } from '../components/StatusBadge'
import { rowEditorPath } from '../dataEditor'
import * as fmt from '../format'
import type { Driver } from '../types'
import { useApi } from '../useApi'

const columns: Column<Driver>[] = [
  {
    key: 'name',
    header: 'Driver',
    render: (driver) => (
      <>
        {driver.DriverName}
        {driver.IsCurrentlyEmployed === false && <span className="tag">Гарсан</span>}
        <span className="cell-sub">{`${driver.EmployeeCode} · ${driver.HomeTerminal}`}</span>
      </>
    ),
    sortValue: (driver) => driver.DriverName,
  },
  {
    key: 'licence',
    header: 'Licence',
    render: (driver) => (
      <>
        {driver.LicenceClass}
        <span className="cell-sub">{`Дуусах: ${fmt.date(driver.LicenceExpiresOn)}`}</span>
      </>
    ),
    sortValue: (driver) => driver.LicenceExpiresOn,
  },
  {
    key: 'adr',
    header: 'ADR',
    render: (driver) => (driver.HasHazmatEndorsement ? 'Тийм' : 'Үгүй'),
    sortValue: (driver) => driver.HasHazmatEndorsement,
  },
  { key: 'trips', header: 'Trips', align: 'right', render: (driver) => fmt.num(driver.TotalTrips), sortValue: (driver) => driver.TotalTrips },
  {
    key: 'distance',
    header: 'Distance',
    align: 'right',
    render: (driver) => `${fmt.num(driver.TotalKmDriven)} км`,
    sortValue: (driver) => driver.TotalKmDriven,
  },
  {
    key: 'hours',
    header: 'Hours',
    align: 'right',
    render: (driver) => fmt.num(driver.TotalHoursOnDuty, 1),
    sortValue: (driver) => driver.TotalHoursOnDuty,
  },
  {
    key: 'lastTrip',
    header: 'Last trip',
    render: (driver) => fmt.date(driver.LastTripDeparture),
    sortValue: (driver) => driver.LastTripDeparture,
  },
  {
    key: 'compliance',
    header: 'Compliance',
    render: (driver) => <StatusBadge value={driver.ComplianceStatus} />,
    sortValue: (driver) => driver.ComplianceStatus,
  },
]

export function DriversPage() {
  const navigate = useNavigate()
  const state = useApi<Driver[]>('/drivers')
  const [search, setSearch] = useState('')
  const [compliance, setCompliance] = useState('')

  return (
    <>
      <PageHeader title="Жолооч нар" subtitle="Ачаалал ба жолооны үнэмлэхийн хүчинтэй байдал. Мөр дээр дарж засна." />
      <Loadable state={state}>
        {(drivers) => {
          const statuses = [...new Set(drivers.map((driver) => driver.ComplianceStatus))].sort()
          const term = search.trim().toLowerCase()
          const rows = drivers.filter(
            (driver) =>
              (!compliance || driver.ComplianceStatus === compliance) &&
              (!term || `${driver.DriverName} ${driver.EmployeeCode} ${driver.HomeTerminal}`.toLowerCase().includes(term)),
          )
          return (
            <>
              <div className="toolbar">
                <input
                  className="input search"
                  type="search"
                  placeholder="Нэр, код эсвэл терминалаар хайх"
                  aria-label="Жолооч хайх"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                />
                <select
                  className="select"
                  aria-label="Үнэмлэхийн төлөвөөр шүүх"
                  value={compliance}
                  onChange={(event) => setCompliance(event.target.value)}
                >
                  <option value="">Бүх төлөв</option>
                  {statuses.map((status) => (
                    <option key={status} value={status}>
                      {fmt.humanize(status)}
                    </option>
                  ))}
                </select>
              </div>
              <Card>
                <DataTable
                  columns={columns}
                  rows={rows}
                  rowKey={(driver) => driver.DriverId}
                  onRowClick={(driver) => navigate(rowEditorPath('Drivers', { DriverId: driver.DriverId }))}
                  initialSort={{ key: 'name', direction: 'asc' }}
                  empty="Тохирох жолооч алга."
                />
              </Card>
            </>
          )
        }}
      </Loadable>
    </>
  )
}
