import { Route, Routes } from 'react-router'
import { Layout } from './components/Layout'
import { RequireAuth } from './components/RequireAuth'
import { AccountPage } from './pages/AccountPage'
import { CustomerDetailPage } from './pages/CustomerDetailPage'
import { CustomersPage } from './pages/CustomersPage'
import { DataRowPage } from './pages/DataRowPage'
import { DataTablePage } from './pages/DataTablePage'
import { DataTablesPage } from './pages/DataTablesPage'
import { DriversPage } from './pages/DriversPage'
import { FleetPage } from './pages/FleetPage'
import { InvoiceDetailPage } from './pages/InvoiceDetailPage'
import { InvoicesPage } from './pages/InvoicesPage'
import { LanesPage } from './pages/LanesPage'
import { LoginPage } from './pages/LoginPage'
import { NewShipmentPage } from './pages/NewShipmentPage'
import { NotFoundPage } from './pages/NotFoundPage'
import { OverviewPage } from './pages/OverviewPage'
import { ShipmentDetailPage } from './pages/ShipmentDetailPage'
import { ShipmentsPage } from './pages/ShipmentsPage'

export default function App() {
  return (
    <Routes>
      <Route path="login" element={<LoginPage />} />
      {/* Signed-out visitors land on the sign-in page. */}
      <Route element={<RequireAuth />}>
        <Route element={<Layout />}>
          <Route index element={<OverviewPage />} />
          <Route path="shipments" element={<ShipmentsPage />} />
          <Route path="shipments/new" element={<NewShipmentPage />} />
          <Route path="shipments/:id" element={<ShipmentDetailPage />} />
          <Route path="customers" element={<CustomersPage />} />
          <Route path="customers/:id" element={<CustomerDetailPage />} />
          <Route path="invoices" element={<InvoicesPage />} />
          <Route path="invoices/:id" element={<InvoiceDetailPage />} />
          <Route path="fleet" element={<FleetPage />} />
          <Route path="drivers" element={<DriversPage />} />
          <Route path="lanes" element={<LanesPage />} />
          <Route path="data" element={<DataTablesPage />} />
          <Route path="data/:table" element={<DataTablePage />} />
          <Route path="data/:table/row" element={<DataRowPage />} />
          <Route path="account" element={<AccountPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Route>
    </Routes>
  )
}
