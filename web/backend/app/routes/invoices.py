from datetime import date
from decimal import Decimal
from typing import Annotated, Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from ..db import Connection, fetch_all, fetch_one, to_dicts

router = APIRouter(tags=["invoices"])

InvoiceStatus = Literal["Draft", "Issued", "PartiallyPaid", "Paid", "Overdue", "Cancelled"]

INVOICE_COLUMNS = """
    i.InvoiceId, i.InvoiceNumber, i.CustomerId, c.CustomerCode, c.LegalName AS CustomerName,
    i.IssueDate, i.DueDate, i.Status, i.Subtotal, i.TaxAmount, i.TotalAmount,
    ISNULL(p.Paid, 0) AS AmountPaid, i.TotalAmount - ISNULL(p.Paid, 0) AS BalanceDue,
    o.DaysOverdue, o.AgeingBucket
"""

INVOICE_SOURCE = """
    FROM dbo.Invoices AS i
    JOIN dbo.Customers AS c ON c.CustomerId = i.CustomerId
    OUTER APPLY (SELECT SUM(Amount) AS Paid FROM dbo.Payments WHERE InvoiceId = i.InvoiceId) AS p
    LEFT JOIN dbo.vw_OutstandingInvoices AS o ON o.InvoiceId = i.InvoiceId
"""


class NewPayment(BaseModel):
    payment_method_id: int
    amount: Annotated[Decimal, Field(gt=0, max_digits=12, decimal_places=2)]
    reference_number: Annotated[str, Field(min_length=1, max_length=50)]
    paid_on: date | None = None


@router.get("/invoices")
def list_invoices(conn: Connection, status: InvoiceStatus | None = None, outstanding: bool = False):
    where, params = [], []
    if status:
        where.append("i.Status = ?")
        params.append(status)
    if outstanding:
        where.append("o.InvoiceId IS NOT NULL")
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    rows = fetch_all(
        conn,
        f"SELECT {INVOICE_COLUMNS} {INVOICE_SOURCE} {where_sql} ORDER BY i.IssueDate DESC, i.InvoiceId DESC;",
        *params,
    )
    ageing = fetch_all(
        conn,
        """
        SELECT AgeingBucket, COUNT(*) AS Invoices, SUM(BalanceDue) AS BalanceDue
        FROM dbo.vw_OutstandingInvoices
        GROUP BY AgeingBucket
        ORDER BY MIN(ISNULL(DaysOverdue, 0));
        """,
    )
    return {"rows": rows, "ageing": ageing}


@router.get("/invoices/{invoice_id}")
def get_invoice(invoice_id: int, conn: Connection):
    invoice = fetch_one(conn, f"SELECT {INVOICE_COLUMNS}, i.Notes {INVOICE_SOURCE} WHERE i.InvoiceId = ?;", invoice_id)
    if invoice is None:
        raise HTTPException(status_code=404, detail="Invoice not found.")
    invoice["lines"] = fetch_all(
        conn,
        """
        SELECT l.LineNumber, l.ShipmentId, s.TrackingNumber, l.Description, l.NetAmount, l.TaxRate,
               l.TaxAmount, l.LineTotal
        FROM dbo.InvoiceLines AS l
        JOIN dbo.Shipments AS s ON s.ShipmentId = l.ShipmentId
        WHERE l.InvoiceId = ?
        ORDER BY l.LineNumber;
        """,
        invoice_id,
    )
    invoice["payments"] = fetch_all(
        conn,
        """
        SELECT p.PaymentId, p.PaidOn, p.Amount, p.ReferenceNumber, m.MethodName
        FROM dbo.Payments AS p
        JOIN dbo.PaymentMethods AS m ON m.PaymentMethodId = p.PaymentMethodId
        WHERE p.InvoiceId = ?
        ORDER BY p.PaidOn, p.PaymentId;
        """,
        invoice_id,
    )
    return invoice


@router.post("/invoices/{invoice_id}/payments")
def record_payment(invoice_id: int, payment: NewPayment, conn: Connection):
    """Posts through dbo.usp_RecordPayment; its trigger keeps the invoice status in step."""
    cursor = conn.execute(
        "{CALL dbo.usp_RecordPayment (?, ?, ?, ?, ?)}",
        invoice_id,
        payment.payment_method_id,
        payment.amount,
        payment.reference_number.strip(),
        payment.paid_on,
    )
    return to_dicts(cursor)[0]
