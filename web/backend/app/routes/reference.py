from fastapi import APIRouter

from ..db import Connection, fetch_all

router = APIRouter(tags=["reference"])


@router.get("/lookups")
def get_lookups(conn: Connection):
    """Everything the booking and payment forms need to fill their dropdowns."""
    return {
        "customers": fetch_all(
            conn, "SELECT CustomerId, CustomerCode, LegalName, IsActive FROM dbo.Customers ORDER BY LegalName;"
        ),
        "lanes": fetch_all(
            conn,
            """
            SELECT l.LaneId, o.TerminalCode AS OriginCode, oc.CityName AS OriginCity,
                   d.TerminalCode AS DestinationCode, dc.CityName AS DestinationCity, l.DistanceKm, l.IsActive
            FROM dbo.Lanes AS l
            JOIN dbo.Terminals AS o ON o.TerminalId = l.OriginTerminalId
            JOIN dbo.Addresses AS oa ON oa.AddressId = o.AddressId
            JOIN dbo.Cities AS oc ON oc.CityId = oa.CityId
            JOIN dbo.Terminals AS d ON d.TerminalId = l.DestinationTerminalId
            JOIN dbo.Addresses AS da ON da.AddressId = d.AddressId
            JOIN dbo.Cities AS dc ON dc.CityId = da.CityId
            ORDER BY o.TerminalCode, d.TerminalCode;
            """,
        ),
        "service_levels": fetch_all(
            conn,
            """
            SELECT ServiceLevelId, ServiceCode, ServiceName, MaxTransitDays
            FROM dbo.ServiceLevels
            WHERE IsActive = 1
            ORDER BY MaxTransitDays DESC;
            """,
        ),
        "cargo_categories": fetch_all(
            conn,
            """
            SELECT CargoCategoryId, CategoryCode, CategoryName, RequiresHazmat, RequiresRefrigeration, MaxDeclaredValue
            FROM dbo.CargoCategories
            ORDER BY CategoryName;
            """,
        ),
        "addresses": fetch_all(
            conn,
            """
            SELECT a.AddressId, a.Line1, a.PostalCode, ci.CityName, co.IsoCode
            FROM dbo.Addresses AS a
            JOIN dbo.Cities AS ci ON ci.CityId = a.CityId
            JOIN dbo.Countries AS co ON co.CountryId = ci.CountryId
            ORDER BY ci.CityName, a.Line1;
            """,
        ),
        "terminals": fetch_all(
            conn,
            "SELECT TerminalId, TerminalCode, TerminalName FROM dbo.Terminals WHERE IsActive = 1 ORDER BY TerminalCode;",
        ),
        "payment_methods": fetch_all(
            conn,
            "SELECT PaymentMethodId, MethodName FROM dbo.PaymentMethods WHERE IsActive = 1 ORDER BY MethodName;",
        ),
    }
