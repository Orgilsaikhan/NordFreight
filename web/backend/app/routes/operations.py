from fastapi import APIRouter

from ..db import Connection, fetch_all

router = APIRouter(tags=["operations"])


@router.get("/fleet")
def list_fleet(conn: Connection):
    return fetch_all(conn, "SELECT * FROM dbo.vw_FleetCostSummary ORDER BY PlateNumber;")


@router.get("/drivers")
def list_drivers(conn: Connection):
    return fetch_all(conn, "SELECT * FROM dbo.vw_DriverUtilisation ORDER BY DriverName;")


@router.get("/lanes")
def list_lanes(conn: Connection):
    return fetch_all(conn, "SELECT * FROM dbo.vw_LanePerformance ORDER BY TotalRevenue DESC;")
