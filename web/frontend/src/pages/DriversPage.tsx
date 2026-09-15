import { useState } from 'react'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Loadable } from '../components/States'
import { StatusBadge } from '../components/StatusBadge'
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
        {driver.IsCurrentlyEmployed === false && <span className="tag">Left</span>}
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
        <span className="cell-sub">{`Expires ${fmt.date(driver.LicenceExpiresOn)}`}</span>
      </>
    ),
    sortValue: (driver) => driver.LicenceExpiresOn,
  },
  {
    key: 'adr',
    header: 'ADR',
    render: (driver) => (driver.HasHazmatEndorsement ? 'Yes' : 'No'),
    sortValue: (driver) => driver.HasHazmatEndorsement,
  },
  { key: 'trips', header: 'Trips', align: 'right', render: (driver) => fmt.num(driver.TotalTrips), sortValue: (driver) => driver.TotalTrips },
  {
    key: 'distance',
    header: 'Distance',
    align: 'right',
    render: (driver) => `${fmt.num(driver.TotalKmDriven)} km`,
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
  const state = useApi<Driver[]>('/drivers')
  const [search, setSearch] = useState('')
  const [compliance, setCompliance] = useState('')

  return (
    <>
      <PageHeader title="Drivers" subtitle="Utilisation and licence compliance" />
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
                  placeholder="Search name, code or terminal"
                  aria-label="Search drivers"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                />
                <select
                  className="select"
                  aria-label="Filter by compliance"
                  value={compliance}
                  onChange={(event) => setCompliance(event.target.value)}
                >
                  <option value="">Any compliance</option>
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
                  initialSort={{ key: 'name', direction: 'asc' }}
                  empty="No drivers match."
                />
              </Card>
            </>
          )
        }}
      </Loadable>
    </>
  )
}
