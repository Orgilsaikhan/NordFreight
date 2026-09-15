/*
  NordFreight Logistics -- 06 - Функцууд
  7 функц, бүгд procedure, триггер эсвэл query-д ашиглагддаг.
  Үнэ: fn_GetEffectiveLaneRateId -> fn_QuoteShipment -> usp_CreateShipment.
  Бусад нь зээл, жолоочийн шалгалт, ачааны түүх, эрсдэлтэй ачааны самбарт.
  Inline TVF-ийг optimizer query дотор задалдаг, параметртэй view шиг ажиллана.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
  fn_GetEffectiveLaneRateId - чиглэл + түвшинд тухайн өдөр хүчинтэй ГАНЦ үнэ.
  TOP (1) ... DESC: хуучин хугацаанууд давхцвал хамгийн сүүлийн үнэ нь ялна.
*/
CREATE OR ALTER FUNCTION dbo.fn_GetEffectiveLaneRateId
(
    @LaneId         INT,
    @ServiceLevelId INT,
    @OnDate         DATE
)
RETURNS INT
AS
BEGIN
    RETURN
    (
        SELECT TOP (1) lr.LaneRateId
        FROM dbo.LaneRates AS lr
        WHERE lr.LaneId         = @LaneId
          AND lr.ServiceLevelId = @ServiceLevelId
          AND lr.EffectiveFrom <= @OnDate
          AND (lr.EffectiveTo IS NULL OR lr.EffectiveTo > @OnDate)
        ORDER BY lr.EffectiveFrom DESC
    );
END;
GO

/*
  fn_QuoteShipment - ачааны үнийг бодно; үнэ байхгүй бол 0 мөр буцаана.
  base = MAX(RatePerKg*жин, MinimumCharge) -> × multiplier -> + шатахуун/handling -> + НӨАТ
  CROSS APPLY (VALUES ...) гинжилснээр алхам бүр өмнөхөө нэрээр нь ашиглана.
*/
CREATE OR ALTER FUNCTION dbo.fn_QuoteShipment
(
    @LaneId          INT,
    @ServiceLevelId  INT,
    @CargoCategoryId INT,
    @WeightKg        DECIMAL(10,2),
    @OnDate          DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        lr.LaneRateId,
        lr.RatePerKg,
        lr.MinimumCharge,
        sl.PriceMultiplier,
        lr.FuelSurchargeRate,
        cc.HandlingSurchargeRate,
        vat.VatRate,
        f.FreightCharge,
        sc.FuelSurcharge,
        sc.HandlingSurcharge,
        CAST(sc.FuelSurcharge + sc.HandlingSurcharge AS DECIMAL(12,2)) AS SurchargeAmount,
        tx.TaxAmount,
        CAST(f.FreightCharge + sc.FuelSurcharge + sc.HandlingSurcharge + tx.TaxAmount
             AS DECIMAL(12,2))                                         AS TotalAmount
    FROM dbo.LaneRates AS lr
    INNER JOIN dbo.ServiceLevels   AS sl ON sl.ServiceLevelId  = lr.ServiceLevelId
    INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = @CargoCategoryId
    -- Энгийн байлгах гээд НӨАТ-ыг тогтмол 20% гэж авсан.
    CROSS APPLY (VALUES (CAST(0.2000 AS DECIMAL(5,4)))) AS vat (VatRate)
    CROSS APPLY (VALUES
    (
        CAST(ROUND(
            CASE WHEN lr.RatePerKg * @WeightKg > lr.MinimumCharge
                 THEN lr.RatePerKg * @WeightKg
                 ELSE lr.MinimumCharge
            END * sl.PriceMultiplier, 2) AS DECIMAL(12,2))
    )) AS f (FreightCharge)
    CROSS APPLY (VALUES
    (
        CAST(ROUND(f.FreightCharge * lr.FuelSurchargeRate,     2) AS DECIMAL(12,2)),
        CAST(ROUND(f.FreightCharge * cc.HandlingSurchargeRate, 2) AS DECIMAL(12,2))
    )) AS sc (FuelSurcharge, HandlingSurcharge)
    CROSS APPLY (VALUES
    (
        CAST(ROUND((f.FreightCharge + sc.FuelSurcharge + sc.HandlingSurcharge) * vat.VatRate, 2)
             AS DECIMAL(12,2))
    )) AS tx (TaxAmount)
    WHERE lr.LaneRateId = dbo.fn_GetEffectiveLaneRateId(@LaneId, @ServiceLevelId, @OnDate)
);
GO

/* fn_CustomerOutstandingBalance - нэхэмжилсэн минус төлсөн, цуцлагдсаныг тооцохгүй. */
CREATE OR ALTER FUNCTION dbo.fn_CustomerOutstandingBalance
(
    @CustomerId INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Invoiced DECIMAL(12,2) =
    (
        SELECT ISNULL(SUM(i.TotalAmount), 0)
        FROM dbo.Invoices AS i
        WHERE i.CustomerId = @CustomerId
          AND i.Status <> N'Cancelled'
    );

    DECLARE @Paid DECIMAL(12,2) =
    (
        SELECT ISNULL(SUM(p.Amount), 0)
        FROM dbo.Payments AS p
        INNER JOIN dbo.Invoices AS i ON i.InvoiceId = p.InvoiceId
        WHERE i.CustomerId = @CustomerId
          AND i.Status <> N'Cancelled'
    );

    RETURN @Invoiced - @Paid;
END;
GO

/*
  fn_CustomerAvailableCredit - лимитээс төлөгдөөгүй нэхэмжлэх болон
  нэхэмжлээгүй ачааг хасна. usp_CreateShipment захиалга авахаас өмнө шалгана.
*/
CREATE OR ALTER FUNCTION dbo.fn_CustomerAvailableCredit
(
    @CustomerId INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @CreditLimit DECIMAL(12,2) =
    (
        SELECT c.CreditLimit FROM dbo.Customers AS c WHERE c.CustomerId = @CustomerId
    );

    IF @CreditLimit IS NULL
        RETURN NULL;                    -- ийм харилцагч байхгүй

    -- Нэхэмжлэхэд ороогүй идэвхтэй ачаанууд
    DECLARE @UnbilledWork DECIMAL(12,2) =
    (
        SELECT ISNULL(SUM(s.TotalAmount), 0)
        FROM dbo.Shipments AS s
        WHERE s.CustomerId = @CustomerId
          AND s.Status <> N'Cancelled'
          AND NOT EXISTS (SELECT 1
                          FROM dbo.InvoiceLines AS il
                          WHERE il.ShipmentId = s.ShipmentId)
    );

    RETURN @CreditLimit
         - dbo.fn_CustomerOutstandingBalance(@CustomerId)
         - @UnbilledWork;
END;
GO

/*
  fn_IsDriverEligible - явах өдөр ажилтан хэвээр, үнэмлэх/гэрчилгээ хүчинтэй,
  ADR бол hazmat зөвшөөрөлтэй эсэх. Алдаа шидэхгүй, 1/0 буцаана.
*/
CREATE OR ALTER FUNCTION dbo.fn_IsDriverEligible
(
    @DriverId       INT,
    @OnDate         DATE,
    @RequiresHazmat BIT
)
RETURNS BIT
AS
BEGIN
    DECLARE @Eligible BIT = 0;

    SELECT @Eligible = 1
    FROM dbo.Drivers AS d
    INNER JOIN dbo.Employees AS e ON e.EmployeeId = d.DriverId
    WHERE d.DriverId = @DriverId
      AND d.LicenceExpiresOn     >= @OnDate
      AND d.MedicalCertExpiresOn >= @OnDate
      AND (e.TerminationDate IS NULL OR e.TerminationDate > @OnDate)
      AND (@RequiresHazmat = 0 OR d.HasHazmatEndorsement = 1);

    RETURN @Eligible;
END;
GO

/*
  fn_GetCustomerShipments - харилцагчийн ачааг огноогоор шүүнэ.
  @FromDate / @ToDate NULL бол тэр талдаа хязгааргүй (dynamic SQL хэрэггүй).
*/
CREATE OR ALTER FUNCTION dbo.fn_GetCustomerShipments
(
    @CustomerId INT,
    @FromDate   DATE,
    @ToDate     DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        sd.ShipmentId,
        sd.TrackingNumber,
        sd.Status,
        sd.OriginTerminal,
        sd.DestinationTerminal,
        sd.ServiceCode,
        sd.CategoryName,
        sd.PickupDate,
        sd.PromisedDeliveryDate,
        sd.ActualDeliveryDate,
        sd.TotalWeightKg,
        sd.TotalAmount,
        sd.DeliveryPerformance,
        sd.DaysLate,
        sd.BillingStatus,
        sd.InvoiceNumber
    FROM dbo.vw_ShipmentDetails AS sd
    WHERE sd.CustomerId = @CustomerId
      AND (@FromDate IS NULL OR sd.PickupDate >= @FromDate)
      AND (@ToDate   IS NULL OR sd.PickupDate <= @ToDate)
);
GO

/*
  fn_ShipmentsAtRisk - хугацаа хэтэрсэн эсвэл удахгүй хэтрэх замдаа яваа ачаа.
  @AsOfDate-ээр огноо өгдөг болохоор тест одоогийн цагаас хамаарахгүй.
*/
CREATE OR ALTER FUNCTION dbo.fn_ShipmentsAtRisk
(
    @AsOfDate       DATE,
    @WarningDays    INT      -- хэд хоног үлдвэл эрсдэлтэй гэж тооцох
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        s.ShipmentId,
        s.TrackingNumber,
        s.Status,
        c.CustomerCode,
        c.LegalName                 AS CustomerName,
        ot.TerminalCode             AS OriginTerminal,
        dt.TerminalCode             AS DestinationTerminal,
        s.PickupDate,
        s.PromisedDeliveryDate,
        DATEDIFF(DAY, s.PromisedDeliveryDate, @AsOfDate)  AS DaysPastPromise,
        s.TotalAmount,
        CASE
            WHEN s.PromisedDeliveryDate <  @AsOfDate THEN 'Breached'
            WHEN s.PromisedDeliveryDate =  @AsOfDate THEN 'Due Today'
            ELSE 'At Risk'
        END                                               AS RiskLevel
    FROM dbo.Shipments AS s
    INNER JOIN dbo.Customers AS c  ON c.CustomerId  = s.CustomerId
    INNER JOIN dbo.Lanes     AS l  ON l.LaneId      = s.LaneId
    INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
    INNER JOIN dbo.Terminals AS dt ON dt.TerminalId = l.DestinationTerminalId
    WHERE s.Status IN (N'Booked', N'PickedUp', N'InTransit', N'OutForDelivery')
      AND s.PromisedDeliveryDate <= DATEADD(DAY, @WarningDays, @AsOfDate)
);
GO

DECLARE @FnCount INT =
(
    SELECT COUNT(*) FROM sys.objects
    WHERE type IN ('FN', 'IF', 'TF') AND schema_id = SCHEMA_ID('dbo')
);
PRINT 'Functions created: ' + CAST(@FnCount AS VARCHAR(10)) + ' (expected 7)';
GO
