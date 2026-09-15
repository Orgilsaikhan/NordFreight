from fastapi import APIRouter

from ..db import Connection, fetch_all, fetch_one

router = APIRouter(tags=["overview"])


@router.get("/overview")
def get_overview(conn: Connection):
    """Headline figures, the revenue trend, shipments at risk and revenue by cargo category."""
    kpis = fetch_one(
        conn,
        """
        SELECT
            (SELECT COUNT(*) FROM dbo.Shipments
             WHERE Status IN (N'Booked', N'PickedUp', N'InTransit', N'OutForDelivery', N'Exception')) AS OpenShipments,
            (SELECT COUNT(*) FROM dbo.Shipments WHERE Status = N'Exception') AS ExceptionShipments,
            (SELECT CAST(100.0 * SUM(IIF(DeliveryPerformance = 'On Time', 1, 0))
                         / NULLIF(SUM(IIF(DeliveryPerformance IN ('On Time', 'Late'), 1, 0)), 0) AS decimal(5, 1))
             FROM dbo.vw_ShipmentDetails
             WHERE ActualDeliveryDate >= DATEADD(DAY, -90, CAST(SYSUTCDATETIME() AS date))) AS OnTimePct90d,
            (SELECT ISNULL(SUM(BalanceDue), 0) FROM dbo.vw_OutstandingInvoices) AS OutstandingBalance,
            (SELECT COUNT(*) FROM dbo.vw_OutstandingInvoices WHERE DaysOverdue > 0) AS OverdueInvoices;
        """,
    )
    revenue_trend = fetch_all(
        conn,
        """
        SELECT MonthStart, TotalRevenue, ShipmentCount, RevenueGrowthPct
        FROM (SELECT TOP (24) * FROM dbo.vw_MonthlyRevenueTrend ORDER BY MonthStart DESC) AS recent
        ORDER BY MonthStart;
        """,
    )
    at_risk = fetch_all(
        conn,
        """
        SELECT TOP (8) ShipmentId, TrackingNumber, Status, CustomerName, OriginTerminal, DestinationTerminal,
               PromisedDeliveryDate, DaysPastPromise, RiskLevel
        FROM dbo.fn_ShipmentsAtRisk(CAST(SYSUTCDATETIME() AS date), 2)
        ORDER BY CASE RiskLevel WHEN 'Breached' THEN 0 WHEN 'Due Today' THEN 1 ELSE 2 END, DaysPastPromise DESC;
        """,
    )
    risk_counts = fetch_all(
        conn,
        """
        SELECT RiskLevel, COUNT(*) AS Shipments
        FROM dbo.fn_ShipmentsAtRisk(CAST(SYSUTCDATETIME() AS date), 2)
        GROUP BY RiskLevel;
        """,
    )
    categories = fetch_all(
        conn,
        """
        SELECT CategoryName, ShipmentCount, TotalRevenue, RevenueSharePct
        FROM dbo.vw_CargoCategoryPerformance
        ORDER BY TotalRevenue DESC;
        """,
    )
    return {
        "kpis": kpis,
        "revenue_trend": revenue_trend,
        "at_risk": at_risk,
        "risk_counts": risk_counts,
        "categories": categories,
    }
