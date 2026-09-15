"""NordFreight web API.

Development:  uv run uvicorn app.main:app --reload   (Vite's dev server proxies /api here)
Production:   build ../frontend with `npm run build`, then `uv run uvicorn app.main:app`
"""

import logging
from contextlib import asynccontextmanager
from pathlib import Path

import pyodbc
from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse

from .auth import current_user, init_store
from .db import describe_error
from .routes import account, customers, invoices, operations, overview, reference, shipments

FRONTEND_DIST = Path(__file__).resolve().parents[2] / "frontend" / "dist"

logger = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_store()
    yield


app = FastAPI(title="NordFreight API", lifespan=lifespan)

# Signing in is public; the account routes check the session themselves where it matters.
app.include_router(account.router, prefix="/api")

# Everything that reads or changes freight data needs a signed-in user.
for module in (overview, shipments, customers, invoices, operations, reference):
    app.include_router(module.router, prefix="/api", dependencies=[Depends(current_user)])


# Plainer wording for unique constraints that a form can run into.
DUPLICATE_MESSAGES = {
    "UQ_Payments_Invoice_Reference": "Энэ нэхэмжлэхэд ийм гүйлгээний дугаартай төлбөр аль хэдийн бүртгэгдсэн байна.",
}


@app.exception_handler(pyodbc.Error)
async def database_error(request: Request, exc: pyodbc.Error) -> JSONResponse:
    number, message = describe_error(exc)
    if number is not None and 50000 <= number <= 50999:
        # THROW from a stored procedure: a business rule refused the change. The message is the database's own.
        return JSONResponse(status_code=422, content={"detail": message})
    if number in (2601, 2627):
        friendly = next((text for name, text in DUPLICATE_MESSAGES.items() if name in message), message)
        return JSONResponse(status_code=409, content={"detail": friendly})
    if number == 547:
        return JSONResponse(status_code=422, content={"detail": message})
    logger.error("Database error on %s %s: %s", request.method, request.url.path, message)
    return JSONResponse(status_code=500, content={"detail": f"Өгөгдлийн сангийн алдаа: {message}"})


# Serve the built React app when it exists; during development Vite serves it instead.
if FRONTEND_DIST.is_dir():
    app.frontend("/", directory=FRONTEND_DIST, fallback="index.html")
