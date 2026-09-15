/*
  NordFreight Logistics -- 05 - View-үүд
  Тайлангийн найман view: JOIN, aggregation, CASE, subquery, window function.
  "06 - Functions.sql"-ийн function-уудыг зориуд дуудаагүй: view үүсэхэд
  бүх объект аль хэдийн байх ёстой, тэгэхгүй бол файлын дараалал эвдэрнэ.
  ORDER BY байхгүй, эрэмбэлэхийг дуудаж буй тал хийнэ.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
  vw_ShipmentDetails
  Ачаа бүрт нэг мөр: FK-уудыг нэр болгоод, цагтаа эсэх, хоног,
  нэхэмжлэлийн төлөвийг тооцоолно. Ихэнх тайлан эндээс эхэлнэ.
*/
CREATE OR ALTER VIEW dbo.vw_ShipmentDetails
AS
SELECT
    s.ShipmentId,
    s.TrackingNumber,
    s.Status,
    c.CustomerId,
    c.CustomerCode,
    c.LegalName                 AS CustomerName,
    ot.TerminalCode             AS OriginTerminal,
    dt.TerminalCode             AS DestinationTerminal,
    oc.CityName                 AS OriginCity,
    dc.CityName                 AS DestinationCity,
    l.LaneId,
    l.DistanceKm,
    sl.ServiceCode,
    sl.ServiceName,
    sl.MaxTransitDays,
    cc.CategoryCode,
    cc.CategoryName,
    s.PickupDate,
    s.PromisedDeliveryDate,
    s.ActualDeliveryDate,
    s.TotalWeightKg,
    s.TotalVolumeM3,
    s.FreightCharge,
    s.SurchargeAmount,
    s.TaxAmount,
    s.TotalAmount,

    -- Хүргэгдээгүй бол ActualTransitDays NULL
    DATEDIFF(DAY, s.PickupDate, s.ActualDeliveryDate)           AS ActualTransitDays,
    DATEDIFF(DAY, s.PickupDate, s.PromisedDeliveryDate)         AS PromisedTransitDays,

    CAST(s.TotalAmount / NULLIF(l.DistanceKm, 0) AS DECIMAL(10,4))   AS RevenuePerKm,
    CAST(s.TotalAmount / NULLIF(s.TotalWeightKg, 0) AS DECIMAL(10,4)) AS RevenuePerKg,

    CASE
        WHEN s.Status = N'Cancelled'                             THEN 'Cancelled'
        WHEN s.ActualDeliveryDate IS NULL                        THEN 'In Progress'
        WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate      THEN 'On Time'
        ELSE 'Late'
    END                                                          AS DeliveryPerformance,

    -- 1/0 flag: AVG() хийвэл цагтаа хүргэлтийн хувь гарна
    CASE
        WHEN s.ActualDeliveryDate IS NULL THEN NULL
        WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate THEN 1
        ELSE 0
    END                                                          AS IsOnTime,

    CASE
        WHEN s.ActualDeliveryDate > s.PromisedDeliveryDate
        THEN DATEDIFF(DAY, s.PromisedDeliveryDate, s.ActualDeliveryDate)
        ELSE 0
    END                                                          AS DaysLate,

    -- LEFT JOIN: нэхэмжлэх гараагүй ачаа ч гарна
    il.InvoiceId,
    inv.InvoiceNumber,
    CASE WHEN il.InvoiceLineId IS NULL THEN 'Not Invoiced'
         ELSE 'Invoiced'
    END                                                          AS BillingStatus
FROM dbo.Shipments        AS s
INNER JOIN dbo.Customers       AS c   ON c.CustomerId      = s.CustomerId
INNER JOIN dbo.Lanes           AS l   ON l.LaneId          = s.LaneId
INNER JOIN dbo.Terminals       AS ot  ON ot.TerminalId     = l.OriginTerminalId
INNER JOIN dbo.Terminals       AS dt  ON dt.TerminalId     = l.DestinationTerminalId
INNER JOIN dbo.Addresses       AS oa  ON oa.AddressId      = s.OriginAddressId
INNER JOIN dbo.Cities          AS oc  ON oc.CityId         = oa.CityId
INNER JOIN dbo.Addresses       AS da  ON da.AddressId      = s.DestinationAddressId
INNER JOIN dbo.Cities          AS dc  ON dc.CityId         = da.CityId
INNER JOIN dbo.ServiceLevels   AS sl  ON sl.ServiceLevelId = s.ServiceLevelId
INNER JOIN dbo.CargoCategories AS cc  ON cc.CargoCategoryId = s.CargoCategoryId
LEFT  JOIN dbo.InvoiceLines    AS il  ON il.ShipmentId     = s.ShipmentId
LEFT  JOIN dbo.Invoices        AS inv ON inv.InvoiceId     = il.InvoiceId;
GO

/*
  vw_CustomerRevenueSummary
  Харилцагч бүрийн нийт тоо баримт. Нэхэмжлэх, төлбөрийг correlated subquery-ээр
  авсан тул ачааны нийлбэр үржигдэхгүй.
*/
CREATE OR ALTER VIEW dbo.vw_CustomerRevenueSummary
AS
SELECT
    c.CustomerId,
    c.CustomerCode,
    c.LegalName,
    c.IsActive,
    c.CreditLimit,
    c.PaymentTermsDays,

    COUNT(s.ShipmentId)                                          AS TotalShipments,
    -- Conditional aggregation: нэг гүйлтээр хэд хэдэн тоо
    COUNT(CASE WHEN s.Status = N'Delivered' THEN 1 END)          AS DeliveredShipments,
    COUNT(CASE WHEN s.Status = N'Cancelled' THEN 1 END)          AS CancelledShipments,
    COUNT(CASE WHEN s.Status NOT IN (N'Delivered', N'Cancelled')
               THEN 1 END)                                       AS OpenShipments,

    ISNULL(SUM(CASE WHEN s.Status <> N'Cancelled'
                    THEN s.TotalAmount END), 0)                  AS LifetimeRevenue,
    ISNULL(AVG(CASE WHEN s.Status <> N'Cancelled'
                    THEN s.TotalAmount END), 0)                  AS AverageShipmentValue,
    ISNULL(SUM(CASE WHEN s.Status <> N'Cancelled'
                    THEN s.TotalWeightKg END), 0)                AS LifetimeWeightKg,

    MIN(s.PickupDate)                                            AS FirstShipmentDate,
    MAX(s.PickupDate)                                            AS LastShipmentDate,
    DATEDIFF(DAY, MAX(s.PickupDate), CAST(SYSUTCDATETIME() AS DATE))
                                                                 AS DaysSinceLastShipment,

    -- Хүргэгдсэн ачаа байхгүй бол NULL
    CAST(100.0 * AVG(CASE WHEN s.ActualDeliveryDate IS NULL THEN NULL
                          WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate THEN 1.0
                          ELSE 0.0 END) AS DECIMAL(5,2))         AS OnTimePercentage,

    -- Өөр grain тул subquery; GROUP BY руу JOIN хийвэл нийлбэр хөөрөгдөнө
    (
        SELECT ISNULL(SUM(i.TotalAmount), 0)
        FROM dbo.Invoices AS i
        WHERE i.CustomerId = c.CustomerId
          AND i.Status <> N'Cancelled'
    )                                                            AS TotalInvoiced,
    (
        SELECT ISNULL(SUM(p.Amount), 0)
        FROM dbo.Payments AS p
        INNER JOIN dbo.Invoices AS i2 ON i2.InvoiceId = p.InvoiceId
        WHERE i2.CustomerId = c.CustomerId
          AND i2.Status <> N'Cancelled'
    )                                                            AS TotalPaid,
    (
        SELECT ISNULL(SUM(i.TotalAmount), 0)
        FROM dbo.Invoices AS i
        WHERE i.CustomerId = c.CustomerId
          AND i.Status <> N'Cancelled'
    )
    -
    (
        SELECT ISNULL(SUM(p.Amount), 0)
        FROM dbo.Payments AS p
        INNER JOIN dbo.Invoices AS i2 ON i2.InvoiceId = p.InvoiceId
        WHERE i2.CustomerId = c.CustomerId
          AND i2.Status <> N'Cancelled'
    )                                                            AS OutstandingBalance
FROM dbo.Customers AS c
LEFT JOIN dbo.Shipments AS s ON s.CustomerId = c.CustomerId
GROUP BY
    c.CustomerId, c.CustomerCode, c.LegalName,
    c.IsActive, c.CreditLimit, c.PaymentTermsDays;
GO

/*
  vw_MonthlyRevenueTrend
  Сар бүрийн орлого, өмнөх сартай харьцуулалт. LAG() тул self-join хэрэггүй.
*/
CREATE OR ALTER VIEW dbo.vw_MonthlyRevenueTrend
AS
WITH MonthlyTotals AS
(
    SELECT
        DATEFROMPARTS(YEAR(s.PickupDate), MONTH(s.PickupDate), 1) AS MonthStart,
        COUNT(*)                        AS ShipmentCount,
        COUNT(DISTINCT s.CustomerId)    AS ActiveCustomers,
        SUM(s.FreightCharge)            AS FreightRevenue,
        SUM(s.SurchargeAmount)          AS SurchargeRevenue,
        SUM(s.TotalAmount)              AS TotalRevenue,
        SUM(s.TotalWeightKg)            AS TotalWeightKg,
        AVG(s.TotalAmount)              AS AverageShipmentValue
    FROM dbo.Shipments AS s
    WHERE s.Status <> N'Cancelled'
    GROUP BY DATEFROMPARTS(YEAR(s.PickupDate), MONTH(s.PickupDate), 1)
)
SELECT
    MonthStart,
    YEAR(MonthStart)                    AS RevenueYear,
    MONTH(MonthStart)                   AS RevenueMonth,
    DATENAME(MONTH, MonthStart)         AS MonthName,
    ShipmentCount,
    ActiveCustomers,
    FreightRevenue,
    SurchargeRevenue,
    TotalRevenue,
    TotalWeightKg,
    CAST(AverageShipmentValue AS DECIMAL(12,2)) AS AverageShipmentValue,

    LAG(TotalRevenue) OVER (ORDER BY MonthStart)                 AS PreviousMonthRevenue,
    TotalRevenue - LAG(TotalRevenue) OVER (ORDER BY MonthStart)  AS RevenueChange,
    CAST(100.0 * (TotalRevenue - LAG(TotalRevenue) OVER (ORDER BY MonthStart))
         / NULLIF(LAG(TotalRevenue) OVER (ORDER BY MonthStart), 0)
         AS DECIMAL(8,2))                                        AS RevenueGrowthPct,

    SUM(TotalRevenue) OVER (ORDER BY MonthStart
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                                 AS CumulativeRevenue,

    -- 3 сарын дундаж улирлын хэлбэлзлийг зөөлрүүлнэ
    CAST(AVG(TotalRevenue) OVER (ORDER BY MonthStart
                                 ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
         AS DECIMAL(12,2))                                       AS ThreeMonthMovingAvg
FROM MonthlyTotals;
GO

/*
  vw_CargoCategoryPerformance
  Ангилал бүрийн орлого, эзлэх хувь. PARTITION-гүй SUM() OVER () мөр бүрт
  нийт дүнг өгдөг тул хоёр дахь query хэрэггүй.
*/
CREATE OR ALTER VIEW dbo.vw_CargoCategoryPerformance
AS
WITH CategoryTotals AS
(
    SELECT
        cc.CargoCategoryId,
        cc.CategoryCode,
        cc.CategoryName,
        cc.RequiresHazmat,
        cc.RequiresRefrigeration,
        cc.HandlingSurchargeRate,
        COUNT(s.ShipmentId)                     AS ShipmentCount,
        ISNULL(SUM(s.TotalAmount), 0)           AS TotalRevenue,
        ISNULL(SUM(s.TotalWeightKg), 0)         AS TotalWeightKg,
        ISNULL(AVG(s.TotalAmount), 0)           AS AverageShipmentValue
    FROM dbo.CargoCategories AS cc
    LEFT JOIN dbo.Shipments AS s
           ON s.CargoCategoryId = cc.CargoCategoryId
          AND s.Status <> N'Cancelled'
    GROUP BY
        cc.CargoCategoryId, cc.CategoryCode, cc.CategoryName,
        cc.RequiresHazmat, cc.RequiresRefrigeration, cc.HandlingSurchargeRate
)
SELECT
    CargoCategoryId,
    CategoryCode,
    CategoryName,
    RequiresHazmat,
    RequiresRefrigeration,
    HandlingSurchargeRate,
    ShipmentCount,
    TotalRevenue,
    TotalWeightKg,
    CAST(AverageShipmentValue AS DECIMAL(12,2))                  AS AverageShipmentValue,
    CAST(TotalRevenue / NULLIF(TotalWeightKg, 0) AS DECIMAL(10,4)) AS RevenuePerKg,

    CAST(100.0 * TotalRevenue / NULLIF(SUM(TotalRevenue) OVER (), 0)
         AS DECIMAL(5,2))                                        AS RevenueSharePct,
    RANK() OVER (ORDER BY TotalRevenue DESC)                     AS RevenueRank,
    RANK() OVER (ORDER BY ShipmentCount DESC)                    AS VolumeRank
FROM CategoryTotals;
GO

/*
  vw_LanePerformance
  Чиглэл бүрийн ачаа, км тутмын орлого, цагтаа хүргэлтийн хувь.
*/
CREATE OR ALTER VIEW dbo.vw_LanePerformance
AS
SELECT
    l.LaneId,
    ot.TerminalCode                     AS OriginTerminal,
    dt.TerminalCode                     AS DestinationTerminal,
    ot.TerminalCode + ' -> ' + dt.TerminalCode                   AS LaneName,
    l.DistanceKm,
    l.EstimatedDrivingHours,
    l.IsActive,

    COUNT(s.ShipmentId)                                          AS ShipmentCount,
    ISNULL(SUM(s.TotalAmount), 0)                                AS TotalRevenue,
    ISNULL(SUM(s.TotalWeightKg), 0)                              AS TotalWeightKg,
    CAST(ISNULL(AVG(s.TotalAmount), 0) AS DECIMAL(12,2))         AS AverageShipmentValue,

    -- Урт өөр чиглэлүүдийг км тутмын орлогоор харьцуулна
    CAST(ISNULL(SUM(s.TotalAmount), 0) / NULLIF(l.DistanceKm, 0)
         AS DECIMAL(12,2))                                       AS TotalRevenuePerKm,

    COUNT(CASE WHEN s.ActualDeliveryDate IS NOT NULL THEN 1 END) AS DeliveredCount,
    COUNT(CASE WHEN s.ActualDeliveryDate > s.PromisedDeliveryDate
               THEN 1 END)                                       AS LateCount,
    CAST(100.0 * AVG(CASE WHEN s.ActualDeliveryDate IS NULL THEN NULL
                          WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate THEN 1.0
                          ELSE 0.0 END) AS DECIMAL(5,2))         AS OnTimePercentage,
    CAST(AVG(CAST(DATEDIFF(DAY, s.PickupDate, s.ActualDeliveryDate) AS DECIMAL(6,2)))
         AS DECIMAL(6,2))                                        AS AvgActualTransitDays
FROM dbo.Lanes AS l
INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
INNER JOIN dbo.Terminals AS dt ON dt.TerminalId = l.DestinationTerminalId
LEFT  JOIN dbo.Shipments AS s  ON s.LaneId = l.LaneId
                              AND s.Status <> N'Cancelled'
GROUP BY
    l.LaneId, ot.TerminalCode, dt.TerminalCode,
    l.DistanceKm, l.EstimatedDrivingHours, l.IsActive;
GO

/*
  vw_DriverUtilisation
  Жолооч бүрийн рейс, км, цаг болон бичиг баримтын төлөв.
  Employees/Drivers 1:1-ийг TripDrivers many-to-many-тэй холбосон.
*/
CREATE OR ALTER VIEW dbo.vw_DriverUtilisation
AS
SELECT
    d.DriverId,
    e.EmployeeCode,
    e.FirstName + ' ' + e.LastName                               AS DriverName,
    t.TerminalCode                                               AS HomeTerminal,
    d.LicenceClass,
    d.LicenceExpiresOn,
    d.HasHazmatEndorsement,
    e.IsCurrentlyEmployed,

    COUNT(tr.TripId)                                             AS TotalTrips,
    COUNT(CASE WHEN td.DriverRole = N'Primary'  THEN 1 END)      AS TripsAsPrimary,
    COUNT(CASE WHEN td.DriverRole = N'CoDriver' THEN 1 END)      AS TripsAsCoDriver,
    COUNT(CASE WHEN tr.Status = N'Completed'    THEN 1 END)      AS CompletedTrips,
    COUNT(DISTINCT tr.VehicleId)                                 AS DistinctVehiclesDriven,

    ISNULL(SUM(tr.EndOdometerKm - tr.StartOdometerKm), 0)        AS TotalKmDriven,
    CAST(ISNULL(SUM(DATEDIFF(MINUTE, tr.ActualDeparture, tr.ActualArrival)), 0) / 60.0
         AS DECIMAL(10,2))                                       AS TotalHoursOnDuty,
    MAX(tr.ScheduledDeparture)                                   AS LastTripDeparture,

    CASE WHEN d.LicenceExpiresOn     < CAST(SYSUTCDATETIME() AS DATE) THEN 'Licence Expired'
         WHEN d.MedicalCertExpiresOn < CAST(SYSUTCDATETIME() AS DATE) THEN 'Medical Expired'
         WHEN d.LicenceExpiresOn     < DATEADD(DAY, 60, CAST(SYSUTCDATETIME() AS DATE))
              THEN 'Licence Expiring Soon'
         ELSE 'Valid'
    END                                                          AS ComplianceStatus
FROM dbo.Drivers    AS d
INNER JOIN dbo.Employees AS e  ON e.EmployeeId = d.DriverId
INNER JOIN dbo.Terminals AS t  ON t.TerminalId = e.HomeTerminalId
LEFT  JOIN dbo.TripDrivers AS td ON td.DriverId = d.DriverId
LEFT  JOIN dbo.Trips       AS tr ON tr.TripId   = td.TripId
GROUP BY
    d.DriverId, e.EmployeeCode, e.FirstName, e.LastName, t.TerminalCode,
    d.LicenceClass, d.LicenceExpiresOn, d.MedicalCertExpiresOn,
    d.HasHazmatEndorsement, e.IsCurrentlyEmployed;
GO

/*
  vw_OutstandingInvoices
  Нээлттэй нэхэмжлэхийн авлагын насжилт. WHERE нь IX_Invoices_Outstanding-тэй таарна.
*/
CREATE OR ALTER VIEW dbo.vw_OutstandingInvoices
AS
SELECT
    i.InvoiceId,
    i.InvoiceNumber,
    i.CustomerId,
    c.CustomerCode,
    c.LegalName                         AS CustomerName,
    i.IssueDate,
    i.DueDate,
    i.Status,
    i.Subtotal,
    i.TaxAmount,
    i.TotalAmount,
    ISNULL(p.AmountPaid, 0)                                      AS AmountPaid,
    i.TotalAmount - ISNULL(p.AmountPaid, 0)                      AS BalanceDue,
    p.LastPaymentDate,

    DATEDIFF(DAY, i.DueDate, CAST(SYSUTCDATETIME() AS DATE))     AS DaysOverdue,
    CASE
        WHEN i.DueDate >= CAST(SYSUTCDATETIME() AS DATE)                    THEN 'Current'
        WHEN DATEDIFF(DAY, i.DueDate, CAST(SYSUTCDATETIME() AS DATE)) <= 30 THEN '1-30 days'
        WHEN DATEDIFF(DAY, i.DueDate, CAST(SYSUTCDATETIME() AS DATE)) <= 60 THEN '31-60 days'
        WHEN DATEDIFF(DAY, i.DueDate, CAST(SYSUTCDATETIME() AS DATE)) <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END                                                          AS AgeingBucket
FROM dbo.Invoices AS i
INNER JOIN dbo.Customers AS c ON c.CustomerId = i.CustomerId
OUTER APPLY
(
    SELECT SUM(pay.Amount) AS AmountPaid,
           MAX(pay.PaidOn) AS LastPaymentDate
    FROM dbo.Payments AS pay
    WHERE pay.InvoiceId = i.InvoiceId
) AS p
WHERE i.Status IN (N'Issued', N'PartiallyPaid', N'Overdue');
GO

/*
  vw_FleetCostSummary
  Машин бүрийн засварын зардал, рейс, км тутмын зардал.
  Хоёр OUTER APPLY тусдаа тул нийлбэрүүд үржигдэхгүй.
*/
CREATE OR ALTER VIEW dbo.vw_FleetCostSummary
AS
SELECT
    v.VehicleId,
    v.PlateNumber,
    v.Make + ' ' + v.Model              AS Vehicle,
    v.ModelYear,
    vt.TypeCode,
    vt.TypeName                         AS VehicleType,
    vt.MaxPayloadKg,
    t.TerminalCode                      AS HomeTerminal,
    v.Status,
    v.OdometerKm,
    DATEDIFF(YEAR, v.AcquiredOn, CAST(SYSUTCDATETIME() AS DATE)) AS AgeYears,

    ISNULL(m.MaintenanceEvents, 0)                               AS MaintenanceEvents,
    ISNULL(m.TotalMaintenanceCost, 0)                            AS TotalMaintenanceCost,
    ISNULL(m.TotalDownTimeHours, 0)                              AS TotalDownTimeHours,
    m.LastServiceDate,

    ISNULL(tp.TripCount, 0)                                      AS TripCount,
    ISNULL(tp.KmDriven, 0)                                       AS KmDriven,
    ISNULL(tp.FuelLitres, 0)                                     AS FuelLitres,

    CAST(ISNULL(m.TotalMaintenanceCost, 0) / NULLIF(tp.KmDriven, 0)
         AS DECIMAL(10,4))                                       AS MaintenanceCostPerKm,
    CAST(100.0 * ISNULL(tp.FuelLitres, 0) / NULLIF(tp.KmDriven, 0)
         AS DECIMAL(8,2))                                        AS LitresPer100Km
FROM dbo.Vehicles AS v
INNER JOIN dbo.VehicleTypes AS vt ON vt.VehicleTypeId = v.VehicleTypeId
INNER JOIN dbo.Terminals    AS t  ON t.TerminalId     = v.HomeTerminalId
OUTER APPLY
(
    SELECT COUNT(*)              AS MaintenanceEvents,
           SUM(mr.TotalCost)     AS TotalMaintenanceCost,
           SUM(mr.DownTimeHours) AS TotalDownTimeHours,
           MAX(mr.PerformedOn)   AS LastServiceDate
    FROM dbo.MaintenanceRecords AS mr
    WHERE mr.VehicleId = v.VehicleId
) AS m
OUTER APPLY
(
    SELECT COUNT(*)                                       AS TripCount,
           SUM(tr.EndOdometerKm - tr.StartOdometerKm)     AS KmDriven,
           SUM(tr.FuelLitres)                             AS FuelLitres
    FROM dbo.Trips AS tr
    WHERE tr.VehicleId = v.VehicleId
      AND tr.Status = N'Completed'
) AS tp;
GO

DECLARE @ViewCount INT = (SELECT COUNT(*) FROM sys.views WHERE schema_id = SCHEMA_ID('dbo'));
PRINT 'Views created: ' + CAST(@ViewCount AS VARCHAR(10)) + ' (expected 8)';
GO
