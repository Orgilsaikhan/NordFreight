# NordFreight website

A small operations site for `NordFreightDB`: a FastAPI backend that talks to SQL Server through pyodbc, and a React frontend built with Vite.

| Page | What it shows |
|------|---------------|
| Overview | Headline figures, monthly revenue, shipments at risk, revenue by cargo category |
| Shipments | Search and filter every booking; open one to see items, status history and trips, or move it to its next status |
| New shipment | Book freight with a live price from `fn_QuoteShipment` |
| Customers | Accounts, contacts, paged shipments and invoices |
| Invoices | Receivables ageing; record a payment against an open invoice |
| Fleet, Drivers, Lanes | The reporting views, sortable |

## Requirements

- SQL Server Express instance `.\SQLEXPRESS` with `NordFreightDB` restored, reachable with Windows authentication
- ODBC Driver 18 for SQL Server
- [uv](https://docs.astral.sh/uv/) (Python 3.11+) and Node.js 20.19+

The instance only accepts Shared Memory connections, so the backend connects with `Server=lpc:.\SQLEXPRESS`. Override it with environment variables if that changes:

| Variable | Default |
|----------|---------|
| `MSSQL_SERVER` | `lpc:.\SQLEXPRESS` |
| `MSSQL_DATABASE` | `NordFreightDB` |
| `MSSQL_DRIVER` | `ODBC Driver 18 for SQL Server` |

## Run it for development

Start the API, then the frontend, in two terminals:

```powershell
cd web\backend
uv run uvicorn app.main:app --reload --port 8000
```

```powershell
cd web\frontend
npm install
npm run dev
```

Open http://localhost:5173. Vite forwards `/api` requests to the backend. The API docs are at http://localhost:8000/docs.

## Run it as one server

```powershell
cd web\frontend
npm run build
cd ..\backend
uv run uvicorn app.main:app --port 8000
```

Open http://localhost:8000. When `frontend/dist` exists, FastAPI serves the built site alongside the API.

## Writes go through the stored procedures

The site never writes to tables directly. Every change calls the procedure that owns the business rules:

| Action | Endpoint | Procedure |
|--------|----------|-----------|
| Book a shipment | `POST /api/shipments` | `usp_CreateShipment` |
| Change a shipment's status | `POST /api/shipments/{id}/status` | `usp_UpdateShipmentStatus` |
| Record a payment | `POST /api/invoices/{id}/payments` | `usp_RecordPayment` |

When a procedure rejects a change (`THROW` 50000–50999), the API returns HTTP 422 with the procedure's own message, and the page shows it next to the form. Duplicate keys return 409.
