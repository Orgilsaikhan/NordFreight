import { useState } from 'react'
import { Card } from '../components/Card'
import { DataTable, type Column } from '../components/DataTable'
import { PageHeader } from '../components/PageHeader'
import { Loadable } from '../components/States'
import { StatusBadge } from '../components/StatusBadge'
import * as fmt from '../format'
import type { Vehicle } from '../types'
import { useApi } from '../useApi'

const columns: Column<Vehicle>[] = [
  { key: 'plate', header: 'Plate', render: (vehicle) => vehicle.PlateNumber, sortValue: (vehicle) => vehicle.PlateNumber },
  {
    key: 'vehicle',
    header: 'Vehicle',
    render: (vehicle) => (
      <>
        {`${vehicle.Vehicle} (${vehicle.ModelYear})`}
        <span className="cell-sub">{`${vehicle.VehicleType} · ${vehicle.HomeTerminal}`}</span>
      </>
    ),
    sortValue: (vehicle) => vehicle.Vehicle,
  },
  {
    key: 'status',
    header: 'Status',
    render: (vehicle) => <StatusBadge value={vehicle.Status} />,
    sortValue: (vehicle) => vehicle.Status,
  },
  {
    key: 'odometer',
    header: 'Odometer',
    align: 'right',
    render: (vehicle) => `${fmt.num(vehicle.OdometerKm)} км`,
    sortValue: (vehicle) => vehicle.OdometerKm,
  },
  { key: 'trips', header: 'Trips', align: 'right', render: (vehicle) => fmt.num(vehicle.TripCount), sortValue: (vehicle) => vehicle.TripCount },
  {
    key: 'maintenance',
    header: 'Maintenance',
    align: 'right',
    render: (vehicle) => fmt.money(vehicle.TotalMaintenanceCost),
    sortValue: (vehicle) => vehicle.TotalMaintenanceCost,
  },
  {
    key: 'costPerKm',
    header: 'Cost / km',
    align: 'right',
    render: (vehicle) => fmt.preciseMoney(vehicle.MaintenanceCostPerKm),
    sortValue: (vehicle) => vehicle.MaintenanceCostPerKm,
  },
  {
    key: 'fuel',
    header: 'L / 100 km',
    align: 'right',
    render: (vehicle) => fmt.num(vehicle.LitresPer100Km, 1),
    sortValue: (vehicle) => vehicle.LitresPer100Km,
  },
  {
    key: 'service',
    header: 'Last service',
    render: (vehicle) => fmt.date(vehicle.LastServiceDate),
    sortValue: (vehicle) => vehicle.LastServiceDate,
  },
]

export function FleetPage() {
  const state = useApi<Vehicle[]>('/fleet')
  const [search, setSearch] = useState('')

  return (
    <>
      <PageHeader title="Авто парк" subtitle="Засвар үйлчилгээний зардал, түлшний зарцуулалт" />
      <div className="toolbar">
        <input
          className="input search"
          type="search"
          placeholder="Улсын дугаар, машин эсвэл терминалаар хайх"
          aria-label="Машин хайх"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
      </div>
      <Card>
        <Loadable state={state}>
          {(vehicles) => {
            const term = search.trim().toLowerCase()
            const rows = term
              ? vehicles.filter((vehicle) =>
                  `${vehicle.PlateNumber} ${vehicle.Vehicle} ${vehicle.VehicleType} ${vehicle.HomeTerminal}`
                    .toLowerCase()
                    .includes(term),
                )
              : vehicles
            return (
              <DataTable
                columns={columns}
                rows={rows}
                rowKey={(vehicle) => vehicle.VehicleId}
                initialSort={{ key: 'plate', direction: 'asc' }}
                empty="Тохирох машин алга."
              />
            )
          }}
        </Loadable>
      </Card>
    </>
  )
}
