from typing import Annotated

from fastapi import APIRouter, HTTPException, Query

from ..db import Connection, fetch_all, fetch_one, result_sets
from .shipments import ShipmentStatus

router = APIRouter(tags=["customers"])


@router.get("/customers")
def list_customers(conn: Connection):
    return fetch_all(
        conn,
        """
        SELECT CustomerId, CustomerCode, LegalName, IsActive, CreditLimit, TotalShipments, OpenShipments,
               LifetimeRevenue, OnTimePercentage, OutstandingBalance, LastShipmentDate, DaysSinceLastShipment
        FROM dbo.vw_CustomerRevenueSummary
        ORDER BY LifetimeRevenue DESC;
        """,
    )


@router.get("/customers/{customer_id}")
def get_customer(customer_id: int, conn: Connection):
    customer = fetch_one(
        conn,
        """
        SELECT v.*, c.TradingName, c.TaxNumber, c.OnboardedOn,
               a.Line1 AS BillingLine1, a.PostalCode AS BillingPostalCode, ci.CityName AS BillingCity,
               co.CountryName AS BillingCountry,
               dbo.fn_CustomerAvailableCredit(c.CustomerId) AS AvailableCredit
        FROM dbo.vw_CustomerRevenueSummary AS v
        JOIN dbo.Customers AS c ON c.CustomerId = v.CustomerId
        JOIN dbo.Addresses AS a ON a.AddressId = c.BillingAddressId
        JOIN dbo.Cities AS ci ON ci.CityId = a.CityId
        JOIN dbo.Countries AS co ON co.CountryId = ci.CountryId
        WHERE v.CustomerId = ?;
        """,
        customer_id,
    )
    if customer is None:
        raise HTTPException(status_code=404, detail="Харилцагч олдсонгүй.")
    customer["contacts"] = fetch_all(
        conn,
        """
        SELECT ContactId, FullName, JobTitle, Email, Phone, IsPrimary
        FROM dbo.CustomerContacts
        WHERE CustomerId = ?
        ORDER BY IsPrimary DESC, FullName;
        """,
        customer_id,
    )
    customer["invoices"] = fetch_all(
        conn,
        """
        SELECT i.InvoiceId, i.InvoiceNumber, i.IssueDate, i.DueDate, i.Status, i.TotalAmount,
               i.TotalAmount - ISNULL(p.Paid, 0) AS BalanceDue
        FROM dbo.Invoices AS i
        OUTER APPLY (SELECT SUM(Amount) AS Paid FROM dbo.Payments WHERE InvoiceId = i.InvoiceId) AS p
        WHERE i.CustomerId = ?
        ORDER BY i.IssueDate DESC, i.InvoiceId DESC;
        """,
        customer_id,
    )
    return customer


@router.get("/customers/{customer_id}/shipments")
def list_customer_shipments(
    customer_id: int,
    conn: Connection,
    status: ShipmentStatus | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
):
    """Paged through dbo.usp_GetCustomerShipments, which returns the total as an OUTPUT parameter."""
    cursor = conn.execute(
        """
        SET NOCOUNT ON;
        DECLARE @TotalRows int;
        EXEC dbo.usp_GetCustomerShipments
             @CustomerId = ?, @Status = ?, @PageNumber = ?, @PageSize = ?, @TotalRows = @TotalRows OUTPUT;
        SELECT @TotalRows AS TotalRows;
        """,
        customer_id,
        status,
        page,
        page_size,
    )
    shipments, totals = result_sets(cursor)
    return {"rows": shipments, "total": totals[0]["TotalRows"]}
