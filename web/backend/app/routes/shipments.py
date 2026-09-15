from datetime import date
from decimal import Decimal
from typing import Annotated, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from ..db import Connection, fetch_all, fetch_one, like_pattern, to_dicts

router = APIRouter(tags=["shipments"])

ShipmentStatus = Literal["Booked", "PickedUp", "InTransit", "OutForDelivery", "Delivered", "Exception", "Cancelled"]
PackagingType = Literal["Pallet", "Crate", "Box", "Drum", "Bag", "Roll"]

# Mirrors the transition table in dbo.usp_UpdateShipmentStatus, which remains the authority.
NEXT_STATUSES: dict[str, list[str]] = {
    "Booked": ["PickedUp", "Exception", "Cancelled"],
    "PickedUp": ["InTransit", "Exception", "Cancelled"],
    "InTransit": ["OutForDelivery", "Exception", "Cancelled"],
    "OutForDelivery": ["Delivered", "Exception"],
    "Exception": ["InTransit", "OutForDelivery", "Delivered", "Cancelled"],
}


class ShipmentItem(BaseModel):
    description: Annotated[str, Field(min_length=1, max_length=200)]
    packaging_type: PackagingType
    quantity: Annotated[int, Field(gt=0)]
    unit_weight_kg: Annotated[Decimal, Field(gt=0, max_digits=9, decimal_places=3)]
    unit_volume_m3: Annotated[Decimal, Field(gt=0, max_digits=9, decimal_places=4)]


class NewShipment(BaseModel):
    customer_id: int
    lane_id: int
    service_level_id: int
    cargo_category_id: int
    origin_address_id: int
    destination_address_id: int
    pickup_date: date | None = None
    declared_value: Annotated[Decimal, Field(ge=0, max_digits=12, decimal_places=2)] = Decimal(0)
    is_insured: bool = False
    items: Annotated[list[ShipmentItem], Field(min_length=1, max_length=50)]


class StatusChange(BaseModel):
    status: ShipmentStatus
    terminal_id: int | None = None
    delivery_date: date | None = None
    notes: Annotated[str | None, Field(max_length=400)] = None


class QuoteRequest(BaseModel):
    lane_id: int
    service_level_id: int
    cargo_category_id: int
    weight_kg: Annotated[Decimal, Field(gt=0, max_digits=12)]
    pickup_date: date | None = None


@router.get("/shipments")
def list_shipments(
    conn: Connection,
    q: str | None = None,
    status: ShipmentStatus | None = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 25,
):
    where, params = [], []
    if q and q.strip():
        where.append("(TrackingNumber LIKE ? OR CustomerName LIKE ? OR CustomerCode LIKE ?)")
        params += [like_pattern(q)] * 3
    if status:
        where.append("Status = ?")
        params.append(status)
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""

    total = fetch_one(conn, f"SELECT COUNT(*) AS Total FROM dbo.vw_ShipmentDetails {where_sql};", *params)
    rows = fetch_all(
        conn,
        f"""
        SELECT ShipmentId, TrackingNumber, Status, CustomerId, CustomerName, OriginTerminal, DestinationTerminal,
               ServiceCode, CategoryName, PickupDate, PromisedDeliveryDate, ActualDeliveryDate, TotalAmount,
               DeliveryPerformance, DaysLate, BillingStatus
        FROM dbo.vw_ShipmentDetails
        {where_sql}
        ORDER BY PickupDate DESC, ShipmentId DESC
        OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;
        """,
        *params,
        (page - 1) * page_size,
        page_size,
    )
    return {"rows": rows, "total": total["Total"] if total else 0}


@router.post("/shipments/quote")
def quote_shipment(request: QuoteRequest, conn: Connection):
    """Prices a prospective booking with dbo.fn_QuoteShipment; null when no rate is on file."""
    return fetch_one(
        conn,
        """
        SELECT FreightCharge, SurchargeAmount, TaxAmount, TotalAmount
        FROM dbo.fn_QuoteShipment(?, ?, ?, ?, COALESCE(?, CAST(SYSUTCDATETIME() AS date)));
        """,
        request.lane_id,
        request.service_level_id,
        request.cargo_category_id,
        request.weight_kg,
        request.pickup_date,
    )


@router.post("/shipments", status_code=201)
def create_shipment(shipment: NewShipment, conn: Connection):
    """Books through dbo.usp_CreateShipment, which prices, credit-checks and writes the shipment atomically."""
    items = [
        (line, item.description.strip(), item.quantity, item.unit_weight_kg, item.unit_volume_m3, item.packaging_type)
        for line, item in enumerate(shipment.items, start=1)
    ]
    cursor = conn.execute(
        "{CALL dbo.usp_CreateShipment (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)}",
        shipment.customer_id,
        shipment.lane_id,
        shipment.service_level_id,
        shipment.cargo_category_id,
        shipment.origin_address_id,
        shipment.destination_address_id,
        items,
        shipment.pickup_date,
        shipment.declared_value,
        shipment.is_insured,
    )
    return to_dicts(cursor)[0]


@router.get("/shipments/{shipment_id}")
def get_shipment(shipment_id: int, conn: Connection):
    shipment = fetch_one(conn, "SELECT * FROM dbo.vw_ShipmentDetails WHERE ShipmentId = ?;", shipment_id)
    if shipment is None:
        raise HTTPException(status_code=404, detail="Shipment not found.")
    shipment |= fetch_one(
        conn,
        """
        SELECT s.DeclaredValue, s.IsInsured, s.BookedAt,
               oa.Line1 + N', ' + oa.PostalCode + N' ' + oc.CityName AS OriginAddress,
               da.Line1 + N', ' + da.PostalCode + N' ' + dc.CityName AS DestinationAddress
        FROM dbo.Shipments AS s
        JOIN dbo.Addresses AS oa ON oa.AddressId = s.OriginAddressId
        JOIN dbo.Cities AS oc ON oc.CityId = oa.CityId
        JOIN dbo.Addresses AS da ON da.AddressId = s.DestinationAddressId
        JOIN dbo.Cities AS dc ON dc.CityId = da.CityId
        WHERE s.ShipmentId = ?;
        """,
        shipment_id,
    ) or {}
    shipment["items"] = fetch_all(
        conn,
        """
        SELECT LineNumber, Description, Quantity, PackagingType, UnitWeightKg, UnitVolumeM3, LineWeightKg, LineVolumeM3
        FROM dbo.ShipmentItems
        WHERE ShipmentId = ?
        ORDER BY LineNumber;
        """,
        shipment_id,
    )
    shipment["history"] = fetch_all(
        conn,
        """
        SELECT h.StatusHistoryId, h.OldStatus, h.NewStatus, h.ChangedAt, h.ChangedBy, t.TerminalCode, h.Notes
        FROM dbo.ShipmentStatusHistory AS h
        LEFT JOIN dbo.Terminals AS t ON t.TerminalId = h.TerminalId
        WHERE h.ShipmentId = ?
        ORDER BY h.ChangedAt DESC, h.StatusHistoryId DESC;
        """,
        shipment_id,
    )
    shipment["trips"] = fetch_all(
        conn,
        """
        SELECT tr.TripId, tr.TripNumber, tr.Status, ts.StopSequence, ts.LegType,
               o.TerminalCode AS OriginTerminal, d.TerminalCode AS DestinationTerminal,
               tr.ScheduledDeparture, tr.ActualDeparture, tr.ActualArrival, v.PlateNumber,
               (SELECT STRING_AGG(e.FirstName + N' ' + e.LastName + IIF(td.DriverRole = N'CoDriver', N' (co-driver)', N''), N', ')
                FROM dbo.TripDrivers AS td
                JOIN dbo.Employees AS e ON e.EmployeeId = td.DriverId
                WHERE td.TripId = tr.TripId) AS Crew
        FROM dbo.TripShipments AS ts
        JOIN dbo.Trips AS tr ON tr.TripId = ts.TripId
        JOIN dbo.Terminals AS o ON o.TerminalId = tr.OriginTerminalId
        JOIN dbo.Terminals AS d ON d.TerminalId = tr.DestinationTerminalId
        JOIN dbo.Vehicles AS v ON v.VehicleId = tr.VehicleId
        WHERE ts.ShipmentId = ?
        ORDER BY tr.ScheduledDeparture;
        """,
        shipment_id,
    )
    shipment["next_statuses"] = NEXT_STATUSES.get(shipment["Status"], [])
    return shipment


@router.post("/shipments/{shipment_id}/status")
def change_status(shipment_id: int, change: StatusChange, conn: Connection):
    """Moves the shipment through dbo.usp_UpdateShipmentStatus; its trigger writes the audit row."""
    cursor = conn.execute(
        "{CALL dbo.usp_UpdateShipmentStatus (?, ?, ?, ?, ?)}",
        shipment_id,
        change.status,
        change.terminal_id,
        change.delivery_date,
        change.notes.strip() if change.notes and change.notes.strip() else None,
    )
    return to_dicts(cursor)[0]
