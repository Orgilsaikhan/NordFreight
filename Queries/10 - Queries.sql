/*
  NordFreight Logistics -- 10 - Query-нууд
  Энгийнээс ахисан түвшин хүртэлх жишээ query-нууд, сүүлд нь бизнесийн асуултууд.
  Query бүр бие даасан тул тусад нь ажиллуулж болно; огноо өнөөдрөөс хамаарна.
  Хэсгүүд: Энгийн Q01-07, Дунд Q08-16, Ахисан Q17-33,
  Бизнес Q34-47, View/function/procedure Q48-53.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1-р хэсэг - Энгийн query-нууд */

-- Q01. SELECT / WHERE / ORDER BY - хамгийн өндөр зээлийн лимиттэй идэвхтэй харилцагчид.
SELECT
    CustomerCode,
    LegalName,
    CreditLimit,
    PaymentTermsDays
FROM dbo.Customers
WHERE IsActive = 1
ORDER BY CreditLimit DESC, CustomerCode;
GO

-- Q02. DISTINCT - бид яг аль хотуудаас ачаа авдаг вэ (давхардалгүй хотын жагсаалт).
SELECT DISTINCT
    co.CountryName,
    ci.CityName
FROM dbo.Shipments AS s
INNER JOIN dbo.Addresses AS a  ON a.AddressId  = s.OriginAddressId
INNER JOIN dbo.Cities    AS ci ON ci.CityId    = a.CityId
INNER JOIN dbo.Countries AS co ON co.CountryId = ci.CountryId
ORDER BY co.CountryName, ci.CityName;
GO

-- Q03. TOP - сүүлийн 90 хоногийн хамгийн хүнд 10 ачаа.
SELECT TOP (10)
    TrackingNumber,
    PickupDate,
    TotalWeightKg,
    TotalVolumeM3,
    TotalAmount,
    Status
FROM dbo.Shipments
WHERE PickupDate >= DATEADD(DAY, -90, CAST(SYSUTCDATETIME() AS DATE))
ORDER BY TotalWeightKg DESC;
GO

-- Q04. TOP ... WITH TIES - хамгийн урт чиглэлүүд; ижил зайтай хосыг (A->B, B->A) таслахгүй.
SELECT TOP (3) WITH TIES
    LaneId,
    OriginTerminalId,
    DestinationTerminalId,
    DistanceKm,
    EstimatedDrivingHours
FROM dbo.Lanes
ORDER BY DistanceKm DESC;
GO

-- Q05. WHERE + огнооны тооцоо - үнэмлэх эсвэл эрүүл мэндийн гэрчилгээ нь 90 хоногт дуусах жолооч нар.
SELECT
    DriverId,
    LicenceNumber,
    LicenceClass,
    LicenceExpiresOn,
    MedicalCertExpiresOn
FROM dbo.Drivers
WHERE LicenceExpiresOn     <= DATEADD(DAY, 90, CAST(SYSUTCDATETIME() AS DATE))
   OR MedicalCertExpiresOn <= DATEADD(DAY, 90, CAST(SYSUTCDATETIME() AS DATE))
ORDER BY LicenceExpiresOn;
GO

-- Q06. IN / NOT IN - яг одоо рейсэнд гаргаж болохгүй машинууд.
SELECT
    PlateNumber,
    Make,
    Model,
    ModelYear,
    Status
FROM dbo.Vehicles
WHERE Status IN (N'InMaintenance', N'Retired', N'OnTrip')
ORDER BY Status, PlateNumber;
GO

-- Q07. LIKE ба BETWEEN - нэг ширхэг нь 100-150 кг жинтэй аюултай ачааны (UN дугаартай) мөрүүд.
SELECT
    si.ShipmentId,
    si.LineNumber,
    si.Description,
    si.Quantity,
    si.UnitWeightKg,
    si.PackagingType
FROM dbo.ShipmentItems AS si
WHERE si.Description LIKE N'UN[0-9][0-9][0-9][0-9]%'
  AND si.UnitWeightKg BETWEEN 100 AND 150
ORDER BY si.UnitWeightKg DESC, si.ShipmentId;
GO

/* 2-р хэсэг - Дунд түвшний query-нууд */

-- Q08. INNER JOIN (5 хүснэгт) - сүүлийн 7 хоногийн ачаа, id-ний оронд нэрүүдтэй.
SELECT
    s.TrackingNumber,
    c.CustomerCode,
    ot.TerminalCode + N' -> ' + dt.TerminalCode AS Lane,
    sl.ServiceCode,
    s.PickupDate,
    s.PromisedDeliveryDate,
    s.Status,
    s.TotalAmount
FROM dbo.Shipments AS s
INNER JOIN dbo.Customers     AS c  ON c.CustomerId      = s.CustomerId
INNER JOIN dbo.Lanes         AS l  ON l.LaneId          = s.LaneId
INNER JOIN dbo.Terminals     AS ot ON ot.TerminalId     = l.OriginTerminalId
INNER JOIN dbo.Terminals     AS dt ON dt.TerminalId     = l.DestinationTerminalId
INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = s.ServiceLevelId
WHERE s.PickupDate BETWEEN DATEADD(DAY, -7, CAST(SYSUTCDATETIME() AS DATE))
                       AND CAST(SYSUTCDATETIME() AS DATE)
ORDER BY s.PickupDate DESC, s.TrackingNumber;
GO

-- Q09. LEFT JOIN - харилцагч бүрийн 90 хоногийн ачааны тоо, ачаа явуулаагүй нь ч орно.
SELECT
    c.CustomerCode,
    c.LegalName,
    c.IsActive,
    COUNT(s.ShipmentId)             AS ShipmentsLast90Days,
    ISNULL(SUM(s.TotalAmount), 0)   AS RevenueLast90Days
FROM dbo.Customers AS c
LEFT JOIN dbo.Shipments AS s
       ON s.CustomerId = c.CustomerId
      -- огнооны шүүлтүүр ON-д байх ёстой: WHERE-д бичвэл INNER JOIN болчихно
      AND s.PickupDate >= DATEADD(DAY, -90, CAST(SYSUTCDATETIME() AS DATE))
      AND s.Status <> N'Cancelled'
GROUP BY c.CustomerCode, c.LegalName, c.IsActive
ORDER BY ShipmentsLast90Days DESC, c.CustomerCode;
GO

-- Q10. GROUP BY + aggregate функцууд - үйлчилгээний түвшин бүрийн орлого.
SELECT
    sl.ServiceCode,
    sl.ServiceName,
    COUNT(*)                                  AS Shipments,
    SUM(s.TotalAmount)                        AS TotalRevenue,
    CAST(AVG(s.TotalAmount) AS DECIMAL(12,2)) AS AverageValue,
    MIN(s.TotalAmount)                        AS SmallestShipment,
    MAX(s.TotalAmount)                        AS LargestShipment,
    SUM(s.TotalWeightKg)                      AS TotalWeightKg
FROM dbo.Shipments AS s
INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = s.ServiceLevelId
WHERE s.Status <> N'Cancelled'
GROUP BY sl.ServiceCode, sl.ServiceName
ORDER BY TotalRevenue DESC;
GO

-- Q11. GROUP BY ... HAVING - 12 сард 200-аас олон ачаатай, дундаж нь 400-аас дээш харилцагчид.
-- HAVING нь aggregate-ийн дараа шүүдэг; WHERE-д COUNT(*), AVG() бичиж болохгүй.
SELECT
    c.CustomerCode,
    c.LegalName,
    COUNT(*)                                  AS Shipments,
    CAST(AVG(s.TotalAmount) AS DECIMAL(12,2)) AS AverageValue,
    SUM(s.TotalAmount)                        AS TotalRevenue
FROM dbo.Shipments AS s
INNER JOIN dbo.Customers AS c ON c.CustomerId = s.CustomerId
WHERE s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
  AND s.Status <> N'Cancelled'
GROUP BY c.CustomerCode, c.LegalName
HAVING COUNT(*) > 200
   AND AVG(s.TotalAmount) > 400
ORDER BY TotalRevenue DESC;
GO

-- Q12. CASE ашиглан ангилах - жингийн ангилал бүрийн ачааны тоо, кг тутмын орлого.
SELECT
    WeightBand,
    COUNT(*)                                                  AS Shipments,
    CAST(AVG(TotalAmount) AS DECIMAL(12,2))                   AS AverageValue,
    CAST(SUM(TotalAmount) / SUM(TotalWeightKg) AS DECIMAL(10,4)) AS RevenuePerKg
FROM
(
    SELECT
        TotalAmount,
        TotalWeightKg,
        CASE
            WHEN TotalWeightKg <  500 THEN N'1. Small (< 500 kg)'
            WHEN TotalWeightKg < 2000 THEN N'2. Part load (500 kg - 2 t)'
            WHEN TotalWeightKg < 5000 THEN N'3. Large part load (2 - 5 t)'
            ELSE                           N'4. Heavy (5 t and over)'
        END AS WeightBand
    FROM dbo.Shipments
    WHERE Status <> N'Cancelled'
) AS banded
GROUP BY WeightBand
ORDER BY WeightBand;
GO

-- Q13. Aggregate доторх CASE + OR нөхцөлтэй LEFT JOIN - терминал бүрийн гарсан/орсон ачаа.
SELECT
    t.TerminalCode,
    t.TerminalName,
    CASE WHEN t.IsHub = 1 THEN 'Hub' ELSE 'Depot' END                       AS TerminalType,
    COUNT(CASE WHEN l.OriginTerminalId      = t.TerminalId THEN s.ShipmentId END) AS Outbound,
    COUNT(CASE WHEN l.DestinationTerminalId = t.TerminalId THEN s.ShipmentId END) AS Inbound,
    ISNULL(SUM(CASE WHEN l.OriginTerminalId = t.TerminalId THEN s.TotalWeightKg END), 0)
                                                                            AS OutboundWeightKg
FROM dbo.Terminals AS t
LEFT JOIN dbo.Lanes AS l
       ON t.TerminalId IN (l.OriginTerminalId, l.DestinationTerminalId)
LEFT JOIN dbo.Shipments AS s
       ON s.LaneId = l.LaneId
      AND s.Status <> N'Cancelled'
      AND s.PickupDate >= DATEADD(DAY, -90, CAST(SYSUTCDATETIME() AS DATE))
GROUP BY t.TerminalCode, t.TerminalName, t.IsHub
-- ORDER BY илэрхийлэл дотор alias ашиглаж чадахгүй тул хоёр COUNT-ыг давтаж бичсэн.
ORDER BY COUNT(CASE WHEN l.OriginTerminalId      = t.TerminalId THEN s.ShipmentId END)
       + COUNT(CASE WHEN l.DestinationTerminalId = t.TerminalId THEN s.ShipmentId END) DESC;
GO

-- Q14. GROUP BY ... HAVING - сүүлийн 6 сард цагтаа хүргэлт нь 90%-иас доош чиглэлүүд.
SELECT
    ot.TerminalCode + N' -> ' + dt.TerminalCode                      AS Lane,
    COUNT(*)                                                         AS Delivered,
    SUM(CASE WHEN s.ActualDeliveryDate > s.PromisedDeliveryDate THEN 1 ELSE 0 END) AS Late,
    CAST(100.0 * AVG(CASE WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate
                          THEN 1.0 ELSE 0.0 END) AS DECIMAL(5,2))    AS OnTimePct
FROM dbo.Shipments AS s
INNER JOIN dbo.Lanes     AS l  ON l.LaneId      = s.LaneId
INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
INNER JOIN dbo.Terminals AS dt ON dt.TerminalId = l.DestinationTerminalId
WHERE s.Status = N'Delivered'
  AND s.ActualDeliveryDate >= DATEADD(MONTH, -6, CAST(SYSUTCDATETIME() AS DATE))
GROUP BY ot.TerminalCode, dt.TerminalCode
HAVING AVG(CASE WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate THEN 1.0 ELSE 0.0 END) < 0.90
ORDER BY OnTimePct;
GO

-- Q15. Self join - ажилтан бүр менежерийнхээ хамт; LEFT JOIN менежергүй захирлыг үлдээнэ.
SELECT
    e.EmployeeCode,
    e.FirstName + N' ' + e.LastName                  AS Employee,
    e.JobTitle,
    ISNULL(m.FirstName + N' ' + m.LastName, N'-')    AS ReportsTo,
    ISNULL(m.JobTitle, N'-')                         AS ManagerTitle
FROM dbo.Employees AS e
LEFT JOIN dbo.Employees AS m ON m.EmployeeId = e.ManagerId
WHERE e.IsCurrentlyEmployed = 1
ORDER BY m.EmployeeId, e.EmployeeId;
GO

-- Q16. One-to-one (нэг-нэг) холбоо - жолооч + ажилтны мөр (Drivers.DriverId нь PK ба FK).
SELECT
    e.EmployeeCode,
    e.FirstName + N' ' + e.LastName   AS Driver,
    t.TerminalCode                    AS HomeTerminal,
    d.LicenceClass,
    CASE WHEN d.HasHazmatEndorsement = 1 THEN 'Yes' ELSE 'No' END AS ADR,
    DATEDIFF(YEAR, e.HireDate, CAST(SYSUTCDATETIME() AS DATE))    AS YearsOfService,
    CASE WHEN e.IsCurrentlyEmployed = 1 THEN 'Active' ELSE 'Left' END AS EmploymentStatus
FROM dbo.Employees AS e
INNER JOIN dbo.Drivers   AS d ON d.DriverId   = e.EmployeeId
INNER JOIN dbo.Terminals AS t ON t.TerminalId = e.HomeTerminalId
ORDER BY t.TerminalCode, Driver;
GO

/* 3-р хэсэг - Ахисан түвшний query-нууд */

-- Q17. Scalar subquery - сүүлийн 30 хоногт нийт дунджаас 2 дахин илүү үнэтэй ачаанууд.
SELECT
    s.TrackingNumber,
    s.PickupDate,
    s.TotalAmount,
    CAST((SELECT AVG(TotalAmount) FROM dbo.Shipments WHERE Status <> N'Cancelled')
         AS DECIMAL(12,2)) AS CompanyAverage
FROM dbo.Shipments AS s
WHERE s.PickupDate >= DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE))
  AND s.TotalAmount > 2 * (SELECT AVG(TotalAmount) FROM dbo.Shipments WHERE Status <> N'Cancelled')
ORDER BY s.TotalAmount DESC;
GO

-- Q18. IN (subquery) - Польшоос авсан ачаанууд, гадна query-д JOIN хийхгүйгээр.
SELECT
    s.TrackingNumber,
    s.PickupDate,
    s.Status,
    s.TotalAmount
FROM dbo.Shipments AS s
WHERE s.OriginAddressId IN
(
    SELECT a.AddressId
    FROM dbo.Addresses AS a
    INNER JOIN dbo.Cities    AS ci ON ci.CityId    = a.CityId
    INNER JOIN dbo.Countries AS co ON co.CountryId = ci.CountryId
    WHERE co.IsoCode = 'PL'
)
  AND s.PickupDate >= DATEADD(DAY, -14, CAST(SYSUTCDATETIME() AS DATE))
ORDER BY s.PickupDate DESC;
GO

-- Q19. Correlated subquery - харилцагч бүрийн хамгийн үнэтэй ачаа (дотор query мөр бүрт ажиллана).
SELECT
    c.CustomerCode,
    s.TrackingNumber,
    s.PickupDate,
    s.TotalAmount
FROM dbo.Shipments AS s
INNER JOIN dbo.Customers AS c ON c.CustomerId = s.CustomerId
WHERE s.TotalAmount =
(
    SELECT MAX(s2.TotalAmount)
    FROM dbo.Shipments AS s2
    WHERE s2.CustomerId = s.CustomerId       -- гадна query-тэй холбох хэсэг
)
ORDER BY s.TotalAmount DESC;
GO

-- Q20. Correlated subquery - ижил чиглэл/үйлчилгээний дунджаас 50%-иас илүү үнэтэй ачаа.
SELECT
    s.TrackingNumber,
    s.LaneId,
    s.ServiceLevelId,
    s.TotalWeightKg,
    s.TotalAmount,
    CAST(peer.AvgAmount AS DECIMAL(12,2)) AS PeerAverage
FROM dbo.Shipments AS s
CROSS APPLY
(
    SELECT AVG(s2.TotalAmount) AS AvgAmount
    FROM dbo.Shipments AS s2
    WHERE s2.LaneId         = s.LaneId
      AND s2.ServiceLevelId = s.ServiceLevelId
      AND s2.Status        <> N'Cancelled'
) AS peer
WHERE s.PickupDate >= DATEADD(DAY, -30, CAST(SYSUTCDATETIME() AS DATE))
  AND s.TotalAmount > 1.5 * peer.AvgAmount
ORDER BY s.TotalAmount / peer.AvgAmount DESC;
GO

-- Q21. Recursive CTE - захирлаас эхлээд ManagerId-аар доош явсан байгууллагын бүтэц.
WITH OrgChart AS
(
    -- Anchor: модны орой
    SELECT
        e.EmployeeId,
        e.ManagerId,
        CAST(e.FirstName + N' ' + e.LastName AS NVARCHAR(200))  AS EmployeeName,
        e.JobTitle,
        0                                                       AS Depth,
        CAST(e.FirstName + N' ' + e.LastName AS NVARCHAR(1000)) AS ReportingPath,
        CAST(RIGHT('0000' + CAST(e.EmployeeId AS VARCHAR(10)), 4) AS VARCHAR(1000)) AS SortKey
    FROM dbo.Employees AS e
    WHERE e.ManagerId IS NULL

    UNION ALL

    -- Recursive алхам: дараагийн түвшний ажилтнууд
    SELECT
        e.EmployeeId,
        e.ManagerId,
        CAST(e.FirstName + N' ' + e.LastName AS NVARCHAR(200)),
        e.JobTitle,
        oc.Depth + 1,
        CAST(oc.ReportingPath + N' > ' + e.FirstName + N' ' + e.LastName AS NVARCHAR(1000)),
        CAST(oc.SortKey + '.' + RIGHT('0000' + CAST(e.EmployeeId AS VARCHAR(10)), 4) AS VARCHAR(1000))
    FROM dbo.Employees AS e
    INNER JOIN OrgChart AS oc ON e.ManagerId = oc.EmployeeId
)
SELECT
    REPLICATE(N'    ', Depth) + EmployeeName AS OrgChart,
    JobTitle,
    Depth,
    ReportingPath
FROM OrgChart
ORDER BY SortKey
OPTION (MAXRECURSION 20);   -- 20-оос гүн бол дата алдаатай
GO

-- Q22. Recursive CTE-ээр aggregate хийх - менежер бүрийн доорх нийт хүн (шууд бусыг нь ч).
WITH Chain AS
(
    -- Ажилтан бүр өөрийнхөө "доор"...
    SELECT EmployeeId AS ManagerId, EmployeeId
    FROM dbo.Employees
    WHERE TerminationDate IS NULL

    UNION ALL

    -- ...бас менежерийнхээ дээд хүмүүсийн доор
    SELECT c.ManagerId, e.EmployeeId
    FROM Chain AS c
    INNER JOIN dbo.Employees AS e ON e.ManagerId = c.EmployeeId
    WHERE e.TerminationDate IS NULL
)
SELECT
    m.FirstName + N' ' + m.LastName AS Manager,
    m.JobTitle,
    COUNT(*) - 1                    AS TotalReports    -- өөрийгөө хасна
FROM Chain AS c
INNER JOIN dbo.Employees AS m ON m.EmployeeId = c.ManagerId
GROUP BY m.EmployeeId, m.FirstName, m.LastName, m.JobTitle
HAVING COUNT(*) > 1
ORDER BY TotalReports DESC;
GO

-- Q23. ROW_NUMBER, RANK, DENSE_RANK - зайгаар эрэмбэлсэн чиглэлүүд (ижил зайтай хосууд).
-- Тэнцүү үед: ROW_NUMBER 1,2,3,4 / RANK 1,1,3,3 (үсрэлттэй) / DENSE_RANK 1,1,2,2.
SELECT
    ot.TerminalCode + N' -> ' + dt.TerminalCode         AS Lane,
    l.DistanceKm,
    ROW_NUMBER() OVER (ORDER BY l.DistanceKm DESC, l.LaneId) AS RowNum,
    RANK()       OVER (ORDER BY l.DistanceKm DESC)       AS RankNum,
    DENSE_RANK() OVER (ORDER BY l.DistanceKm DESC)       AS DenseRankNum
FROM dbo.Lanes AS l
INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
INNER JOIN dbo.Terminals AS dt ON dt.TerminalId = l.DestinationTerminalId
ORDER BY l.DistanceKm DESC, l.LaneId;
GO

-- Q24. ROW_NUMBER (групп бүрийн сүүлийн мөр) - Exception-д гацсан ачаа, хэр удсан нь.
WITH LatestEvent AS
(
    SELECT
        h.ShipmentId,
        h.OldStatus,
        h.NewStatus,
        h.ChangedAt,
        ROW_NUMBER() OVER (PARTITION BY h.ShipmentId
                           ORDER BY h.ChangedAt DESC, h.StatusHistoryId DESC) AS rn
    FROM dbo.ShipmentStatusHistory AS h
)
SELECT
    s.TrackingNumber,
    c.CustomerCode,
    le.OldStatus                                              AS PreviousStatus,
    le.NewStatus                                              AS CurrentStatus,
    le.ChangedAt                                              AS SinceUtc,
    DATEDIFF(DAY, le.ChangedAt, SYSUTCDATETIME())             AS DaysInStatus,
    s.TotalAmount
FROM LatestEvent AS le
INNER JOIN dbo.Shipments AS s ON s.ShipmentId = le.ShipmentId
INNER JOIN dbo.Customers AS c ON c.CustomerId = s.CustomerId
WHERE le.rn = 1
  AND s.Status = N'Exception'
ORDER BY DaysInStatus DESC;
GO

-- Q25. LAG ба LEAD - харилцагч бүрийн ачаа явуулсан өдрүүдийн завсар, хамгийн урт завсар.
WITH ShippingDays AS
(
    SELECT DISTINCT CustomerId, PickupDate
    FROM dbo.Shipments
    WHERE Status <> N'Cancelled'
),
Gaps AS
(
    SELECT
        CustomerId,
        PickupDate,
        LAG(PickupDate)  OVER (PARTITION BY CustomerId ORDER BY PickupDate) AS PreviousShippingDay,
        LEAD(PickupDate) OVER (PARTITION BY CustomerId ORDER BY PickupDate) AS NextShippingDay
    FROM ShippingDays
)
SELECT
    c.CustomerCode,
    c.LegalName,
    COUNT(*)                                                           AS ShippingDays,
    CAST(AVG(CAST(DATEDIFF(DAY, g.PreviousShippingDay, g.PickupDate) AS DECIMAL(8,2)))
         AS DECIMAL(8,2))                                              AS AvgDaysBetween,
    MAX(DATEDIFF(DAY, g.PreviousShippingDay, g.PickupDate))            AS LongestGapDays,
    MAX(CASE WHEN g.NextShippingDay IS NULL THEN g.PickupDate END)     AS LastShippingDay
FROM Gaps AS g
INNER JOIN dbo.Customers AS c ON c.CustomerId = g.CustomerId
GROUP BY c.CustomerCode, c.LegalName
ORDER BY LongestGapDays DESC;
GO

-- Q26. PARTITION BY + running total - харилцагч бүрийн сарын орлого, оны эхнээс хуримтлал.
WITH CustomerMonth AS
(
    SELECT
        s.CustomerId,
        DATEFROMPARTS(YEAR(s.PickupDate), MONTH(s.PickupDate), 1) AS MonthStart,
        SUM(s.TotalAmount) AS Revenue
    FROM dbo.Shipments AS s
    WHERE s.Status <> N'Cancelled'
      AND s.PickupDate >= DATEFROMPARTS(YEAR(SYSUTCDATETIME()) - 1, 1, 1)
    GROUP BY s.CustomerId, DATEFROMPARTS(YEAR(s.PickupDate), MONTH(s.PickupDate), 1)
)
SELECT
    c.CustomerCode,
    cm.MonthStart,
    cm.Revenue,
    SUM(cm.Revenue) OVER (PARTITION BY cm.CustomerId, YEAR(cm.MonthStart)
                          ORDER BY cm.MonthStart
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS YearToDate,
    CAST(100.0 * cm.Revenue
         / SUM(cm.Revenue) OVER (PARTITION BY cm.CustomerId, YEAR(cm.MonthStart))
         AS DECIMAL(5,2))                                                  AS PctOfCustomerYear
FROM CustomerMonth AS cm
INNER JOIN dbo.Customers AS c ON c.CustomerId = cm.CustomerId
ORDER BY c.CustomerCode, cm.MonthStart;
GO

-- Q27. NTILE - идэвхтэй харилцагчдыг 12 сарын орлогоор 4 түвшинд хуваана.
WITH Revenue12 AS
(
    SELECT c.CustomerId, c.CustomerCode, c.LegalName,
           ISNULL(SUM(s.TotalAmount), 0) AS Revenue
    FROM dbo.Customers AS c
    LEFT JOIN dbo.Shipments AS s
           ON s.CustomerId = c.CustomerId
          AND s.Status <> N'Cancelled'
          AND s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
    WHERE c.IsActive = 1
    GROUP BY c.CustomerId, c.CustomerCode, c.LegalName
)
SELECT
    CustomerCode,
    LegalName,
    Revenue,
    NTILE(4) OVER (ORDER BY Revenue DESC)       AS Quartile,
    CASE NTILE(4) OVER (ORDER BY Revenue DESC)
        WHEN 1 THEN 'Key Account'
        WHEN 2 THEN 'Growth'
        WHEN 3 THEN 'Standard'
        ELSE        'Nurture / Review'
    END                                         AS Segment
FROM Revenue12
ORDER BY Revenue DESC;
GO

-- Q28. EXISTS - сүүлийн 12 сард аюултай ачаатай рейсэнд явсан ADR жолооч нар.
SELECT
    e.FirstName + N' ' + e.LastName AS Driver,
    d.LicenceNumber
FROM dbo.Drivers AS d
INNER JOIN dbo.Employees AS e ON e.EmployeeId = d.DriverId
WHERE d.HasHazmatEndorsement = 1
  AND EXISTS
  (
      SELECT 1
      FROM dbo.TripDrivers     AS td
      INNER JOIN dbo.Trips           AS t  ON t.TripId           = td.TripId
      INNER JOIN dbo.TripShipments   AS ts ON ts.TripId          = t.TripId
      INNER JOIN dbo.Shipments       AS s  ON s.ShipmentId       = ts.ShipmentId
      INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
      WHERE td.DriverId = d.DriverId
        AND cc.RequiresHazmat = 1
        AND t.ScheduledDeparture >= DATEADD(MONTH, -12, SYSUTCDATETIME())
  )
ORDER BY Driver;
GO

-- Q29. NOT EXISTS - хүргэгдсэн ч нэхэмжлэх нь гараагүй ачаанууд.
-- NOT EXISTS нь NULL-д зөв ажилладаг; NOT IN жагсаалтад NULL орвол чимээгүй 0 мөр буцаана.
SELECT
    c.CustomerCode,
    s.TrackingNumber,
    s.ActualDeliveryDate,
    s.FreightCharge + s.SurchargeAmount     AS NetAmount,
    DATEDIFF(DAY, s.ActualDeliveryDate, CAST(SYSUTCDATETIME() AS DATE)) AS DaysSinceDelivery
FROM dbo.Shipments AS s
INNER JOIN dbo.Customers AS c ON c.CustomerId = s.CustomerId
WHERE s.Status = N'Delivered'
  AND NOT EXISTS (SELECT 1 FROM dbo.InvoiceLines AS il WHERE il.ShipmentId = s.ShipmentId)
ORDER BY DaysSinceDelivery DESC, c.CustomerCode;
GO

-- Q30. Давхар NOT EXISTS (relational division) - 90 хоногт БҮХ идэвхтэй үйлчилгээг ашигласан харилцагчид.
-- "Энэ харилцагчийн ашиглаагүй үйлчилгээ байхгүй" гэж уншина.
SELECT
    c.CustomerCode,
    c.LegalName
FROM dbo.Customers AS c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.ServiceLevels AS sl
    WHERE sl.IsActive = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.Shipments AS s
          WHERE s.CustomerId     = c.CustomerId
            AND s.ServiceLevelId = sl.ServiceLevelId
            AND s.PickupDate    >= DATEADD(DAY, -90, CAST(SYSUTCDATETIME() AS DATE))
      )
)
ORDER BY c.CustomerCode;
GO

-- Q31. Conditional aggregation (гараар хийсэн pivot) - харилцагч бүрийн үйлчилгээ тус бүрээр ачаа.
SELECT
    c.CustomerCode,
    COUNT(*)                                                         AS Shipments,
    COUNT(CASE WHEN sl.ServiceCode = N'ECON' THEN 1 END)             AS Economy,
    COUNT(CASE WHEN sl.ServiceCode = N'STD'  THEN 1 END)             AS Standard,
    COUNT(CASE WHEN sl.ServiceCode = N'EXP'  THEN 1 END)             AS Express,
    COUNT(CASE WHEN sl.ServiceCode = N'NEXT' THEN 1 END)             AS NextDay,
    CAST(100.0 * SUM(CASE WHEN sl.ServiceCode IN (N'EXP', N'NEXT') THEN s.TotalAmount END)
         / SUM(s.TotalAmount) AS DECIMAL(5,2))                       AS PremiumRevenuePct
FROM dbo.Shipments AS s
INNER JOIN dbo.Customers     AS c  ON c.CustomerId      = s.CustomerId
INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = s.ServiceLevelId
WHERE s.Status <> N'Cancelled'
  AND s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
GROUP BY c.CustomerCode
ORDER BY PremiumRevenuePct DESC;
GO

-- Q32. PIVOT оператор - дээрхтэй ижил санаа, гэхдээ орлогоор.
SELECT
    CustomerCode,
    ISNULL([ECON], 0) AS Economy,
    ISNULL([STD],  0) AS Standard,
    ISNULL([EXP],  0) AS Express,
    ISNULL([NEXT], 0) AS NextDay
FROM
(
    SELECT c.CustomerCode, sl.ServiceCode, s.TotalAmount
    FROM dbo.Shipments AS s
    INNER JOIN dbo.Customers     AS c  ON c.CustomerId      = s.CustomerId
    INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = s.ServiceLevelId
    WHERE s.Status <> N'Cancelled'
      AND s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
) AS src
PIVOT
(
    SUM(TotalAmount) FOR ServiceCode IN ([ECON], [STD], [EXP], [NEXT])
) AS pvt
ORDER BY CustomerCode;
GO

-- Q33. Олон хүснэгттэй JOIN + window function - 30 хоногийн рейсийн ачааны жагсаалт, даацын ашиглалт.
SELECT
    t.TripNumber,
    CAST(t.ScheduledDeparture AS DATE)                      AS DepartureDate,
    ot.TerminalCode + N' -> ' + dt.TerminalCode             AS Route,
    v.PlateNumber,
    vt.TypeCode                                             AS VehicleType,
    pe.FirstName + N' ' + pe.LastName                       AS PrimaryDriver,
    ISNULL(ce.FirstName + N' ' + ce.LastName, N'-')         AS CoDriver,
    ts.StopSequence,
    s.TrackingNumber,
    cu.CustomerCode,
    cc.CategoryCode,
    s.TotalWeightKg,
    SUM(s.TotalWeightKg) OVER (PARTITION BY t.TripId)       AS TripLoadKg,
    CAST(100.0 * SUM(s.TotalWeightKg) OVER (PARTITION BY t.TripId) / vt.MaxPayloadKg
         AS DECIMAL(5,2))                                   AS PayloadUtilisationPct,
    COUNT(*) OVER (PARTITION BY t.TripId)                   AS ShipmentsOnTrip
FROM dbo.Trips AS t
INNER JOIN dbo.Terminals       AS ot ON ot.TerminalId      = t.OriginTerminalId
INNER JOIN dbo.Terminals       AS dt ON dt.TerminalId      = t.DestinationTerminalId
INNER JOIN dbo.Vehicles        AS v  ON v.VehicleId        = t.VehicleId
INNER JOIN dbo.VehicleTypes    AS vt ON vt.VehicleTypeId   = v.VehicleTypeId
INNER JOIN dbo.TripDrivers     AS pd ON pd.TripId          = t.TripId AND pd.DriverRole = N'Primary'
INNER JOIN dbo.Employees       AS pe ON pe.EmployeeId      = pd.DriverId
LEFT  JOIN dbo.TripDrivers     AS cd ON cd.TripId          = t.TripId AND cd.DriverRole = N'CoDriver'
LEFT  JOIN dbo.Employees       AS ce ON ce.EmployeeId      = cd.DriverId
INNER JOIN dbo.TripShipments   AS ts ON ts.TripId          = t.TripId
INNER JOIN dbo.Shipments       AS s  ON s.ShipmentId       = ts.ShipmentId
INNER JOIN dbo.Customers       AS cu ON cu.CustomerId      = s.CustomerId
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE t.ScheduledDeparture >= DATEADD(DAY, -30, SYSUTCDATETIME())
ORDER BY t.ScheduledDeparture DESC, t.TripNumber, ts.StopSequence;
GO

-- Q33b. GROUP BY ROLLUP - улс, үйлчилгээгээр орлого + дэд дүн, нийт дүн.
-- GROUPING() нь жинхэнэ NULL-ийг дэд дүнгийн мөрөөс ялгана.
SELECT
    CASE WHEN GROUPING(co.CountryName) = 1 THEN N'** ALL COUNTRIES **'
         ELSE co.CountryName END                           AS OriginCountry,
    CASE WHEN GROUPING(sl.ServiceCode) = 1 THEN N'* subtotal *'
         ELSE sl.ServiceCode END                           AS Service,
    COUNT(*)                                               AS Shipments,
    SUM(s.TotalAmount)                                     AS Revenue
FROM dbo.Shipments AS s
INNER JOIN dbo.Lanes         AS l  ON l.LaneId          = s.LaneId
INNER JOIN dbo.Terminals     AS t  ON t.TerminalId      = l.OriginTerminalId
INNER JOIN dbo.Addresses     AS a  ON a.AddressId       = t.AddressId
INNER JOIN dbo.Cities        AS ci ON ci.CityId         = a.CityId
INNER JOIN dbo.Countries     AS co ON co.CountryId      = ci.CountryId
INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = s.ServiceLevelId
WHERE s.Status <> N'Cancelled'
  AND s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
GROUP BY ROLLUP (co.CountryName, sl.ServiceCode)
ORDER BY GROUPING(co.CountryName), co.CountryName, GROUPING(sl.ServiceCode), sl.ServiceCode;
GO

/* 4-р хэсэг - Бизнес / тайлангийн query-нууд */

-- Q34. Хамгийн их мөнгө зарцуулдаг харилцагчид хэн бэ? (12 сар, эзлэх хувь, Pareto хувь)
WITH Revenue12 AS
(
    SELECT
        c.CustomerCode,
        c.LegalName,
        COUNT(*)            AS Shipments,
        SUM(s.TotalAmount)  AS Revenue
    FROM dbo.Shipments AS s
    INNER JOIN dbo.Customers AS c ON c.CustomerId = s.CustomerId
    WHERE s.Status <> N'Cancelled'
      AND s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
    GROUP BY c.CustomerCode, c.LegalName
)
SELECT
    RANK() OVER (ORDER BY Revenue DESC)                          AS SpendRank,
    CustomerCode,
    LegalName,
    Shipments,
    Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER () AS DECIMAL(5,2)) AS SharePct,
    CAST(100.0 * SUM(Revenue) OVER (ORDER BY Revenue DESC
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
         / SUM(Revenue) OVER () AS DECIMAL(5,2))                 AS CumulativeSharePct
FROM Revenue12
ORDER BY Revenue DESC;
GO

-- Q35. Сарын орлогын чиг хандлага - өмнөх сар/жилтэй харьцуулсан өсөлт, 3 сарын гулсах дундаж.
-- LAG(..., 12) сар бүр мөртэй гэж үзнэ; энэ сар дуусаагүй тул өсөлт нь бага гарна.
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(PickupDate), MONTH(PickupDate), 1) AS MonthStart,
        COUNT(*)            AS Shipments,
        SUM(TotalAmount)    AS Revenue
    FROM dbo.Shipments
    WHERE Status <> N'Cancelled'
      AND PickupDate <= CAST(SYSUTCDATETIME() AS DATE)
    GROUP BY DATEFROMPARTS(YEAR(PickupDate), MONTH(PickupDate), 1)
)
SELECT
    MonthStart,
    Shipments,
    Revenue,
    CAST(100.0 * (Revenue - LAG(Revenue, 1) OVER (ORDER BY MonthStart))
         / NULLIF(LAG(Revenue, 1) OVER (ORDER BY MonthStart), 0) AS DECIMAL(8,2))  AS MoMGrowthPct,
    LAG(Revenue, 12) OVER (ORDER BY MonthStart)                                     AS SameMonthLastYear,
    CAST(100.0 * (Revenue - LAG(Revenue, 12) OVER (ORDER BY MonthStart))
         / NULLIF(LAG(Revenue, 12) OVER (ORDER BY MonthStart), 0) AS DECIMAL(8,2)) AS YoYGrowthPct,
    CAST(AVG(Revenue) OVER (ORDER BY MonthStart ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
         AS DECIMAL(12,2))                                                          AS Rolling3MonthAvg
FROM Monthly
ORDER BY MonthStart;
GO

-- Q36. Аль ангилал хамгийн их орлого оруулдаг вэ, нийт орлогын хэдэн хувийг эзэлдэг вэ?
WITH CategoryRevenue AS
(
    SELECT
        cc.CategoryName,
        COUNT(*)            AS Shipments,
        SUM(s.TotalAmount)  AS Revenue,
        SUM(s.TotalWeightKg) AS WeightKg
    FROM dbo.Shipments AS s
    INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
    WHERE s.Status <> N'Cancelled'
      AND s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
    GROUP BY cc.CategoryName
)
SELECT
    DENSE_RANK() OVER (ORDER BY Revenue DESC)                     AS RevenueRank,
    CategoryName,
    Shipments,
    Revenue,
    CAST(100.0 * Revenue / SUM(Revenue) OVER () AS DECIMAL(5,2))  AS RevenueSharePct,
    CAST(Revenue / WeightKg AS DECIMAL(10,4))                     AS RevenuePerKg
FROM CategoryRevenue
ORDER BY Revenue DESC;
GO

-- Q37. Ачааны ангилал бүрийн топ 3 харилцагч (PARTITION BY ангилал бүрт эрэмбийг шинээр эхлүүлнэ).
WITH CategoryCustomer AS
(
    SELECT
        cc.CategoryName,
        c.CustomerCode,
        c.LegalName,
        SUM(s.TotalAmount) AS Revenue
    FROM dbo.Shipments AS s
    INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
    INNER JOIN dbo.Customers       AS c  ON c.CustomerId       = s.CustomerId
    WHERE s.Status <> N'Cancelled'
      AND s.PickupDate >= DATEADD(MONTH, -12, CAST(SYSUTCDATETIME() AS DATE))
    GROUP BY cc.CategoryName, c.CustomerCode, c.LegalName
),
Ranked AS
(
    SELECT
        CategoryName, CustomerCode, LegalName, Revenue,
        DENSE_RANK() OVER (PARTITION BY CategoryName ORDER BY Revenue DESC) AS RankInCategory,
        CAST(100.0 * Revenue / SUM(Revenue) OVER (PARTITION BY CategoryName)
             AS DECIMAL(5,2))                                               AS ShareOfCategoryPct
    FROM CategoryCustomer
)
SELECT CategoryName, RankInCategory, CustomerCode, LegalName, Revenue, ShareOfCategoryPct
FROM Ranked
WHERE RankInCategory <= 3
ORDER BY CategoryName, RankInCategory;
GO

-- Q38. Аль "бүтээгдэхүүн"-ий (чиглэлийн) борлуулалт буурч байна?
-- Сүүлийн бүтэн 3 сарыг өмнөх 3 сартай нь харьцуулна.
WITH Periods AS
(
    SELECT
        DATEADD(MONTH, -6, m.ThisMonth) AS PriorStart,
        DATEADD(MONTH, -3, m.ThisMonth) AS RecentStart,
        m.ThisMonth                     AS RecentEnd           -- энэ огноо өөрөө орохгүй
    FROM (SELECT DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1) AS ThisMonth) AS m
),
LaneRevenue AS
(
    SELECT
        s.LaneId,
        SUM(CASE WHEN s.PickupDate >= p.RecentStart THEN s.TotalAmount ELSE 0 END) AS RecentRevenue,
        SUM(CASE WHEN s.PickupDate <  p.RecentStart THEN s.TotalAmount ELSE 0 END) AS PriorRevenue
    FROM dbo.Shipments AS s
    CROSS JOIN Periods AS p
    WHERE s.Status <> N'Cancelled'
      AND s.PickupDate >= p.PriorStart
      AND s.PickupDate <  p.RecentEnd
    GROUP BY s.LaneId
)
SELECT
    ot.TerminalCode + N' -> ' + dt.TerminalCode                              AS Lane,
    lr.PriorRevenue,
    lr.RecentRevenue,
    lr.RecentRevenue - lr.PriorRevenue                                       AS Change,
    CAST(100.0 * (lr.RecentRevenue - lr.PriorRevenue) / NULLIF(lr.PriorRevenue, 0)
         AS DECIMAL(8,2))                                                    AS ChangePct,
    CASE
        WHEN lr.RecentRevenue < lr.PriorRevenue * 0.95 THEN 'Declining'
        WHEN lr.RecentRevenue > lr.PriorRevenue * 1.05 THEN 'Growing'
        ELSE 'Stable'
    END                                                                      AS Trend
FROM LaneRevenue AS lr
INNER JOIN dbo.Lanes     AS l  ON l.LaneId      = lr.LaneId
INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
INNER JOIN dbo.Terminals AS dt ON dt.TerminalId = l.DestinationTerminalId
ORDER BY ChangePct;
GO

-- Q39. Аль харилцагчид бага зарцуулж эхэлсэн бэ? (10%-иас их буурсан нь)
WITH Periods AS
(
    SELECT
        DATEADD(MONTH, -6, m.ThisMonth) AS PriorStart,
        DATEADD(MONTH, -3, m.ThisMonth) AS RecentStart,
        m.ThisMonth                     AS RecentEnd
    FROM (SELECT DATEFROMPARTS(YEAR(SYSUTCDATETIME()), MONTH(SYSUTCDATETIME()), 1) AS ThisMonth) AS m
)
SELECT
    c.CustomerCode,
    c.LegalName,
    SUM(CASE WHEN s.PickupDate <  p.RecentStart THEN s.TotalAmount ELSE 0 END) AS PriorQuarter,
    SUM(CASE WHEN s.PickupDate >= p.RecentStart THEN s.TotalAmount ELSE 0 END) AS RecentQuarter,
    CAST(100.0 * (SUM(CASE WHEN s.PickupDate >= p.RecentStart THEN s.TotalAmount ELSE 0 END)
                - SUM(CASE WHEN s.PickupDate <  p.RecentStart THEN s.TotalAmount ELSE 0 END))
         / NULLIF(SUM(CASE WHEN s.PickupDate < p.RecentStart THEN s.TotalAmount ELSE 0 END), 0)
         AS DECIMAL(8,2))                                                      AS ChangePct
FROM dbo.Shipments AS s
INNER JOIN dbo.Customers AS c ON c.CustomerId = s.CustomerId
CROSS JOIN Periods AS p
WHERE s.Status <> N'Cancelled'
  AND s.PickupDate >= p.PriorStart
  AND s.PickupDate <  p.RecentEnd
GROUP BY c.CustomerCode, c.LegalName
HAVING SUM(CASE WHEN s.PickupDate >= p.RecentStart THEN s.TotalAmount ELSE 0 END)
     < 0.90 * SUM(CASE WHEN s.PickupDate < p.RecentStart THEN s.TotalAmount ELSE 0 END)
ORDER BY ChangePct;
GO

-- Q40. Аль харилцагчид 60 хоног юу ч захиалаагүй байна? OUTER APPLY огт захиалаагүйг ч үлдээнэ.
SELECT
    c.CustomerCode,
    c.LegalName,
    CASE WHEN c.IsActive = 1 THEN 'Active account' ELSE 'Closed account' END AS AccountStatus,
    act.LastPickupDate,
    DATEDIFF(DAY, act.LastPickupDate, CAST(SYSUTCDATETIME() AS DATE))        AS DaysSinceLastShipment,
    ISNULL(act.LifetimeRevenue, 0)                                           AS LifetimeRevenue,
    pc.FullName                                                              AS PrimaryContact,
    pc.Email
FROM dbo.Customers AS c
OUTER APPLY
(
    SELECT MAX(s.PickupDate)  AS LastPickupDate,
           SUM(s.TotalAmount) AS LifetimeRevenue
    FROM dbo.Shipments AS s
    WHERE s.CustomerId = c.CustomerId
      AND s.Status <> N'Cancelled'
) AS act
LEFT JOIN dbo.CustomerContacts AS pc
       ON pc.CustomerId = c.CustomerId
      AND pc.IsPrimary  = 1
WHERE act.LastPickupDate IS NULL
   OR act.LastPickupDate < DATEADD(DAY, -60, CAST(SYSUTCDATETIME() AS DATE))
ORDER BY DaysSinceLastShipment DESC;
GO

-- Q41. Бид хүргэлтийн амлалтаа биелүүлж байна уу? Үйлчилгээ бүрийн 6 сарын цагтаа хүргэлт.
SELECT
    sl.ServiceCode,
    sl.ServiceName,
    sl.MaxTransitDays                                                     AS PromisedDays,
    COUNT(*)                                                              AS Delivered,
    CAST(100.0 * AVG(CASE WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate
                          THEN 1.0 ELSE 0.0 END) AS DECIMAL(5,2))         AS OnTimePct,
    CAST(AVG(CAST(DATEDIFF(DAY, s.PickupDate, s.ActualDeliveryDate) AS DECIMAL(6,2)))
         AS DECIMAL(6,2))                                                 AS AvgTransitDays,
    CAST(AVG(CASE WHEN s.ActualDeliveryDate > s.PromisedDeliveryDate
                  THEN CAST(DATEDIFF(DAY, s.PromisedDeliveryDate, s.ActualDeliveryDate) AS DECIMAL(6,2))
             END) AS DECIMAL(6,2))                                        AS AvgDaysLateWhenLate,
    SUM(CASE WHEN s.ActualDeliveryDate > s.PromisedDeliveryDate
             THEN s.TotalAmount ELSE 0 END)                               AS RevenueDeliveredLate
FROM dbo.Shipments AS s
INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = s.ServiceLevelId
WHERE s.Status = N'Delivered'
  AND s.ActualDeliveryDate >= DATEADD(MONTH, -6, CAST(SYSUTCDATETIME() AS DATE))
GROUP BY sl.ServiceCode, sl.ServiceName, sl.MaxTransitDays
ORDER BY sl.MaxTransitDays;
GO

-- Q42. Бидэнд хэдий хэрийн мөнгө өртэй, хэр удсан бэ? vw_OutstandingInvoices-ийн авлагын насжилт.
SELECT
    AgeingBucket,
    COUNT(*)                                                               AS Invoices,
    SUM(BalanceDue)                                                        AS Outstanding,
    CAST(100.0 * SUM(BalanceDue) / SUM(SUM(BalanceDue)) OVER () AS DECIMAL(5,2)) AS PctOfOutstanding
FROM dbo.vw_OutstandingInvoices
GROUP BY AgeingBucket
ORDER BY CASE AgeingBucket
             WHEN 'Current'    THEN 0
             WHEN '1-30 days'  THEN 1
             WHEN '31-60 days' THEN 2
             WHEN '61-90 days' THEN 3
             ELSE 4
         END;
GO

-- Q43. Хэн төлбөрөө хоцорч төлдөг вэ? Харилцагч бүрийн дунджаар төлөх хоног (DSO).
SELECT
    c.CustomerCode,
    c.LegalName,
    c.PaymentTermsDays,
    COUNT(*)                                                            AS PaidInvoices,
    CAST(AVG(CAST(DATEDIFF(DAY, i.IssueDate, p.ClearedOn) AS DECIMAL(8,2)))
         AS DECIMAL(8,2))                                               AS AvgDaysToPay,
    SUM(CASE WHEN p.ClearedOn > i.DueDate THEN 1 ELSE 0 END)            AS PaidLate,
    CAST(100.0 * AVG(CASE WHEN p.ClearedOn > i.DueDate THEN 1.0 ELSE 0.0 END)
         AS DECIMAL(5,2))                                               AS PaidLatePct
FROM dbo.Invoices AS i
INNER JOIN dbo.Customers AS c ON c.CustomerId = i.CustomerId
CROSS APPLY
(
    SELECT MAX(pay.PaidOn) AS ClearedOn
    FROM dbo.Payments AS pay
    WHERE pay.InvoiceId = i.InvoiceId
) AS p
WHERE i.Status = N'Paid'
GROUP BY c.CustomerCode, c.LegalName, c.PaymentTermsDays
ORDER BY PaidLatePct DESC, AvgDaysToPay DESC;
GO

-- Q44. Аль харилцагчид зээлийн лимитдээ ойртсон байна?
-- fn_CustomerAvailableCredit нэхэмжлээгүй ажлыг ч тооцно (usp_CreateShipment-тэй ижил шалгалт).
SELECT
    CustomerCode,
    LegalName,
    CreditLimit,
    OutstandingInvoices,
    AvailableCredit,
    CAST(100.0 * (CreditLimit - AvailableCredit) / NULLIF(CreditLimit, 0)
         AS DECIMAL(6,2))                                           AS CreditUtilisationPct,
    CASE
        WHEN AvailableCredit < 0                   THEN 'Over limit - bookings will be refused'
        WHEN AvailableCredit < CreditLimit * 0.15  THEN 'Near limit'
        ELSE 'OK'
    END                                                             AS CreditStatus
FROM
(
    SELECT
        c.CustomerCode,
        c.LegalName,
        c.CreditLimit,
        dbo.fn_CustomerOutstandingBalance(c.CustomerId) AS OutstandingInvoices,
        dbo.fn_CustomerAvailableCredit(c.CustomerId)    AS AvailableCredit
    FROM dbo.Customers AS c
    WHERE c.IsActive = 1
) AS credit
ORDER BY CreditUtilisationPct DESC;
GO

-- Q45. Аль машинуудын засвар үйлчилгээний цаг болсон бэ? Сүүлийн засвараас хойших км, хоног.
-- OUTER APPLY + TOP (1) машин бүрийн хамгийн сүүлийн засварыг л авна.
SELECT
    v.PlateNumber,
    vt.TypeCode,
    t.TerminalCode                                                  AS HomeTerminal,
    v.Status,
    v.OdometerKm,
    ls.PerformedOn                                                  AS LastServiceDate,
    v.OdometerKm - ls.OdometerKm                                    AS KmSinceService,
    DATEDIFF(DAY, ls.PerformedOn, CAST(SYSUTCDATETIME() AS DATE))   AS DaysSinceService,
    CASE
        WHEN ls.PerformedOn IS NULL                                          THEN 'No service on record'
        WHEN v.OdometerKm - ls.OdometerKm > 60000                            THEN 'OVERDUE - distance'
        WHEN DATEDIFF(DAY, ls.PerformedOn, CAST(SYSUTCDATETIME() AS DATE)) > 365 THEN 'OVERDUE - time'
        WHEN v.OdometerKm - ls.OdometerKm > 45000
          OR DATEDIFF(DAY, ls.PerformedOn, CAST(SYSUTCDATETIME() AS DATE)) > 300 THEN 'Due soon'
        ELSE 'OK'
    END                                                             AS ServiceStatus
FROM dbo.Vehicles AS v
INNER JOIN dbo.VehicleTypes AS vt ON vt.VehicleTypeId = v.VehicleTypeId
INNER JOIN dbo.Terminals    AS t  ON t.TerminalId     = v.HomeTerminalId
OUTER APPLY
(
    SELECT TOP (1) mr.PerformedOn, mr.OdometerKm
    FROM dbo.MaintenanceRecords AS mr
    WHERE mr.VehicleId = v.VehicleId
      AND mr.MaintenanceType IN (N'Scheduled', N'Inspection')
    ORDER BY mr.PerformedOn DESC
) AS ls
WHERE v.Status <> N'Retired'
ORDER BY KmSinceService DESC;
GO

-- Q46. Жолооч нарын чансаа - 90 хоногт явсан км, терминал дотроо болон компанийн хэмжээнд.
WITH DriverActivity AS
(
    SELECT
        td.DriverId,
        COUNT(*)                                                        AS Trips,
        SUM(tr.EndOdometerKm - tr.StartOdometerKm)                      AS KmDriven,
        SUM(DATEDIFF(MINUTE, tr.ActualDeparture, tr.ActualArrival)) / 60.0 AS HoursDriven
    FROM dbo.TripDrivers AS td
    INNER JOIN dbo.Trips AS tr ON tr.TripId = td.TripId
    WHERE tr.Status = N'Completed'
      AND tr.ActualDeparture >= DATEADD(DAY, -90, SYSUTCDATETIME())
    GROUP BY td.DriverId
)
SELECT
    t.TerminalCode                                                      AS HomeTerminal,
    e.FirstName + N' ' + e.LastName                                     AS Driver,
    da.Trips,
    da.KmDriven,
    CAST(da.HoursDriven AS DECIMAL(8,1))                                AS HoursDriven,
    DENSE_RANK() OVER (PARTITION BY t.TerminalCode ORDER BY da.KmDriven DESC) AS RankAtTerminal,
    RANK()       OVER (ORDER BY da.KmDriven DESC)                       AS RankInCompany,
    CAST(100.0 * da.KmDriven / SUM(da.KmDriven) OVER (PARTITION BY t.TerminalCode)
         AS DECIMAL(5,2))                                               AS ShareOfTerminalKmPct
FROM DriverActivity AS da
INNER JOIN dbo.Employees AS e ON e.EmployeeId = da.DriverId
INNER JOIN dbo.Terminals AS t ON t.TerminalId = e.HomeTerminalId
ORDER BY t.TerminalCode, RankAtTerminal;
GO

-- Q47. Машин паркийн багтаамж хаана дэмий үрэгдэж байна? Машины төрөл бүрийн даацын ашиглалт.
WITH TripLoad AS
(
    SELECT
        t.TripId,
        vt.TypeName,
        vt.MaxPayloadKg,
        SUM(s.TotalWeightKg) AS LoadKg,
        COUNT(*)             AS ShipmentsOnTrip
    FROM dbo.Trips AS t
    INNER JOIN dbo.Vehicles      AS v  ON v.VehicleId      = t.VehicleId
    INNER JOIN dbo.VehicleTypes  AS vt ON vt.VehicleTypeId = v.VehicleTypeId
    INNER JOIN dbo.TripShipments AS ts ON ts.TripId        = t.TripId
    INNER JOIN dbo.Shipments     AS s  ON s.ShipmentId     = ts.ShipmentId
    WHERE t.Status = N'Completed'
    GROUP BY t.TripId, vt.TypeName, vt.MaxPayloadKg
)
SELECT
    TypeName,
    COUNT(*)                                                              AS Trips,
    CAST(AVG(CAST(ShipmentsOnTrip AS DECIMAL(6,2))) AS DECIMAL(6,2))      AS AvgShipmentsPerTrip,
    CAST(AVG(100.0 * LoadKg / MaxPayloadKg) AS DECIMAL(5,2))              AS AvgUtilisationPct,
    SUM(CASE WHEN LoadKg < MaxPayloadKg * 0.25 THEN 1 ELSE 0 END)         AS TripsUnder25Pct
FROM TripLoad
GROUP BY TypeName
ORDER BY AvgUtilisationPct;
GO

/* 5-р хэсэг - View, function, procedure ашиглах */

-- Q48. Хамгийн муу үзүүлэлттэй чиглэлүүд, view-ээс шууд.
SELECT TOP (5)
    LaneName, ShipmentCount, TotalRevenue, OnTimePercentage, AvgActualTransitDays
FROM dbo.vw_LanePerformance
WHERE ShipmentCount > 0
ORDER BY OnTimePercentage, ShipmentCount DESC;
GO

-- Q49. Өнөөдрийн асуудалтай ачаа: хугацаа хэтэрсэн эсвэл 1 өдөрт дуусах.
SELECT *
FROM dbo.fn_ShipmentsAtRisk(CAST(SYSUTCDATETIME() AS DATE), 1)
ORDER BY CASE RiskLevel WHEN 'Breached' THEN 0 WHEN 'Due Today' THEN 1 ELSE 2 END,
         DaysPastPromise DESC;
GO

-- Q50. Захиалахгүйгээр үнийн санал авах: 2.5 т хөргүүртэй ачаа, Tallinn -> Riga, Express.
SELECT *
FROM dbo.fn_QuoteShipment(1, 3, 4, 2500.00, CAST(SYSUTCDATETIME() AS DATE));
GO

-- Q51. Нэг харилцагчийн сүүлийн улирлын ачаа (inline TVF).
SELECT TrackingNumber, Status, OriginTerminal, DestinationTerminal,
       PickupDate, TotalAmount, DeliveryPerformance, BillingStatus
FROM dbo.fn_GetCustomerShipments(1, DATEADD(MONTH, -3, CAST(SYSUTCDATETIME() AS DATE)), NULL)
ORDER BY PickupDate DESC;
GO

-- Q52. Харилцагчийн портал: 3-р харилцагчийн хүргэгдсэн ачаа, 1-р хуудас.
DECLARE @TotalRows INT;

EXEC dbo.usp_GetCustomerShipments
     @CustomerId = 3,
     @Status     = N'Delivered',
     @PageNumber = 1,
     @PageSize   = 10,
     @TotalRows  = @TotalRows OUTPUT;

SELECT @TotalRows AS TotalMatchingRows,
       CEILING(@TotalRows / 10.0) AS TotalPages;
GO

-- Q53. Өнгөрсөн сарын менежментийн тайлан (4 result set).
-- EXEC-д илэрхийлэл дамжуулж болохгүй тул он, сарыг эхлээд хувьсагчид авсан.
DECLARE @LastMonth   DATE = DATEADD(MONTH, -1, CAST(SYSUTCDATETIME() AS DATE));
DECLARE @ReportYear  INT  = YEAR(@LastMonth);
DECLARE @ReportMonth INT  = MONTH(@LastMonth);

EXEC dbo.usp_GenerateMonthlyRevenueReport
     @Year         = @ReportYear,
     @Month        = @ReportMonth,
     @TopCustomers = 5;
GO
