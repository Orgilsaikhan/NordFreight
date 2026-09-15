# NordFreight website

A small operations site for `NordFreightDB`: a FastAPI backend that talks to SQL Server through pyodbc, and a React frontend built with Vite.

The interface is in Mongolian. Data stays as stored: table column headers, status values (Delivered, Paid, Breached…), names and descriptions remain in English, and so do the error messages raised by the stored procedures.

| Page | What it shows |
|------|---------------|
| Overview | Headline figures, monthly revenue, shipments at risk, revenue by cargo category |
| Shipments | Search and filter every booking; open one to see items, status history and trips, or move it to its next status |
| New shipment | Book freight with a live price from `fn_QuoteShipment` |
| Customers | Accounts, contacts, paged shipments and invoices |
| Invoices | Receivables ageing; record a payment against an open invoice |
| Fleet, Drivers, Lanes | The reporting views, sortable |

## Signing in

Every page sits behind a sign-in page, which is where signed-out visitors land. All accounts have the same rights: anyone signed in can view and change freight data.

The first time the backend starts it creates one account:

| Username | Password |
|----------|----------|
| `Admin` | `Admin123` |

Change that password on the **Account** page (click your name at the bottom of the sidebar), where you can also add more users.

- Accounts and sessions are stored in `backend/data/auth.sqlite3`, not in NordFreightDB, so they survive `01 - Database Creation.sql` recreating the database. Delete the file to start over with the initial account.
- Passwords are stored as salted scrypt hashes. A session lasts 12 hours and lives in an HttpOnly cookie.
- The database's own audit trail (`ShipmentStatusHistory.ChangedBy`) still records the SQL Server login the API connects as, not the website user.

| Variable | Default | Purpose |
|----------|---------|---------|
| `INITIAL_ADMIN_USERNAME` / `INITIAL_ADMIN_PASSWORD` | `Admin` / `Admin123` | The account created when the store is empty |
| `AUTH_DB_PATH` | `backend/data/auth.sqlite3` | Where accounts and sessions are kept |
| `COOKIE_SECURE` | `false` | Set to `true` when serving over HTTPS |

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
