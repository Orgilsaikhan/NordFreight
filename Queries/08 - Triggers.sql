/*
  NordFreight Logistics -- 08 - Триггерүүд
  3 триггер, зөвхөн CHECK/UNIQUE/индексээр хийж болохгүй дүрмүүдэд.
  Audit гараар хийсэн UPDATE-г ч барих ёстой; төлбөр, даацын дүрэм олон
  хүснэгт/мөр хамардаг. Бүгд set-based: inserted-д ганц мөр гэж бодохгүй.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
  1. TR_Shipments_TrackStatus (Shipments, AFTER INSERT/UPDATE)
  Төлөв өөрчлөгдөх бүрт түүхэнд мөр нэмж, UpdatedAt-ыг шинэчилнэ.
  Өөрийн хүснэгтээ update хийдэг ч RECURSIVE_TRIGGERS OFF тул давталт үүсэхгүй.
*/
CREATE OR ALTER TRIGGER dbo.TR_Shipments_TrackStatus
ON dbo.Shipments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Мөр олоогүй UPDATE ч триггерийг ажиллуулдаг.
    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    -- Шинэ ачааны эхний түүх (deleted-д байхгүй)
    INSERT INTO dbo.ShipmentStatusHistory (ShipmentId, OldStatus, NewStatus, Notes)
    SELECT i.ShipmentId, NULL, i.Status, N'Shipment booked'
    FROM inserted AS i
    WHERE NOT EXISTS (SELECT 1 FROM deleted AS d WHERE d.ShipmentId = i.ShipmentId);

    -- Төлөв өөрчлөгдсөн мөр л (CK_ShipmentStatusHistory_Changed зөрчихгүйн тулд)
    INSERT INTO dbo.ShipmentStatusHistory (ShipmentId, OldStatus, NewStatus, Notes)
    SELECT i.ShipmentId, d.Status, i.Status,
           CASE WHEN i.Status = N'Delivered'
                     AND i.ActualDeliveryDate > i.PromisedDeliveryDate
                THEN N'Delivered late'
                WHEN i.Status = N'Delivered'
                THEN N'Delivered on time'
                ELSE NULL
           END
    FROM inserted AS i
    INNER JOIN deleted AS d ON d.ShipmentId = i.ShipmentId
    WHERE i.Status <> d.Status;

    -- Зөвхөн UPDATE үед (INSERT-д default утга орсон)
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE s
        SET s.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Shipments AS s
        INNER JOIN inserted AS i ON i.ShipmentId = s.ShipmentId;
    END
END;
GO

/*
  2. TR_Payments_MaintainInvoiceStatus (Payments, AFTER INSERT/UPDATE/DELETE)
  Илүү төлөлтийг хориглож, нэхэмжлэхийн төлвийг бодно (2 хүснэгт тул CHECK болохгүй).
  DELETE-г ч барина: төлбөр буцаавал Paid төлөв буцах ёстой.
*/
CREATE OR ALTER TRIGGER dbo.TR_Payments_MaintainInvoiceStatus
ON dbo.Payments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- inserted болон deleted-ээс хөндөгдсөн нэхэмжлэхүүд
    DECLARE @Affected TABLE (InvoiceId INT NOT NULL PRIMARY KEY);

    INSERT INTO @Affected (InvoiceId)
    SELECT InvoiceId FROM inserted
    UNION
    SELECT InvoiceId FROM deleted;

    IF NOT EXISTS (SELECT 1 FROM @Affected)
        RETURN;

    -- Хамгаалалт: төлбөр нэхэмжлэхийн дүнгээс хэтэрч болохгүй
    DECLARE @BadInvoiceId  INT,
            @BadPaid       DECIMAL(12,2),
            @BadTotal      DECIMAL(12,2),
            @BadNumber     NVARCHAR(20);

    SELECT TOP (1)
           @BadInvoiceId = i.InvoiceId,
           @BadNumber    = i.InvoiceNumber,
           @BadPaid      = p.PaidToDate,
           @BadTotal     = i.TotalAmount
    FROM dbo.Invoices AS i
    INNER JOIN @Affected AS a ON a.InvoiceId = i.InvoiceId
    CROSS APPLY
    (
        SELECT ISNULL(SUM(pay.Amount), 0) AS PaidToDate
        FROM dbo.Payments AS pay
        WHERE pay.InvoiceId = i.InvoiceId
    ) AS p
    WHERE p.PaidToDate > i.TotalAmount;

    IF @BadInvoiceId IS NOT NULL
    BEGIN
        DECLARE @Msg NVARCHAR(400) = FORMATMESSAGE(
            'Payments totalling %s exceed the %s total of invoice %s.',
            CAST(@BadPaid  AS NVARCHAR(30)),
            CAST(@BadTotal AS NVARCHAR(30)),
            @BadNumber);
        THROW 50055, @Msg, 1;
    END

    -- Төлвийг төлсөн дүнгээс бодно; Draft, Cancelled-д хүрэхгүй.
    UPDATE i
    SET i.Status = CASE
                       WHEN p.PaidToDate >= i.TotalAmount AND i.TotalAmount > 0
                            THEN N'Paid'
                       WHEN p.PaidToDate > 0
                            THEN N'PartiallyPaid'
                       WHEN i.DueDate < CAST(SYSUTCDATETIME() AS DATE)
                            THEN N'Overdue'
                       ELSE N'Issued'
                   END,
        i.UpdatedAt = SYSUTCDATETIME()
    FROM dbo.Invoices AS i
    INNER JOIN @Affected AS a ON a.InvoiceId = i.InvoiceId
    CROSS APPLY
    (
        SELECT ISNULL(SUM(pay.Amount), 0) AS PaidToDate
        FROM dbo.Payments AS pay
        WHERE pay.InvoiceId = i.InvoiceId
    ) AS p
    WHERE i.Status NOT IN (N'Draft', N'Cancelled');
END;
GO

/*
  3. TR_TripShipments_EnforceCapacity (TripShipments, AFTER INSERT/UPDATE)
  Рейсийн ачааны жагсаалтын нийт жинг машины даацтай харьцуулна.
  Олон мөрийн SUM, 3 хүснэгтийн цаадах лимит - CHECK үүнийг чадахгүй.
*/
CREATE OR ALTER TRIGGER dbo.TR_TripShipments_EnforceCapacity
ON dbo.TripShipments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @TripNumber   NVARCHAR(20),
            @LoadKg       DECIMAL(12,2),
            @MaxPayloadKg DECIMAL(10,2),
            @PlateNumber  NVARCHAR(15);

    SELECT TOP (1)
           @TripNumber   = t.TripNumber,
           @PlateNumber  = v.PlateNumber,
           @LoadKg       = m.LoadKg,
           @MaxPayloadKg = vt.MaxPayloadKg
    FROM dbo.Trips AS t
    INNER JOIN dbo.Vehicles     AS v  ON v.VehicleId     = t.VehicleId
    INNER JOIN dbo.VehicleTypes AS vt ON vt.VehicleTypeId = v.VehicleTypeId
    CROSS APPLY
    (
        -- Зөвхөн шинэ мөр биш, жагсаалт бүхэлдээ
        SELECT ISNULL(SUM(s.TotalWeightKg), 0) AS LoadKg
        FROM dbo.TripShipments AS ts
        INNER JOIN dbo.Shipments AS s ON s.ShipmentId = ts.ShipmentId
        WHERE ts.TripId = t.TripId
    ) AS m
    WHERE t.TripId IN (SELECT TripId FROM inserted)
      AND m.LoadKg > vt.MaxPayloadKg;

    IF @TripNumber IS NOT NULL
    BEGIN
        DECLARE @Msg NVARCHAR(400) = FORMATMESSAGE(
            'Trip %s is overloaded: %s kg of freight on vehicle %s, rated %s kg.',
            @TripNumber,
            CAST(@LoadKg       AS NVARCHAR(30)),
            @PlateNumber,
            CAST(@MaxPayloadKg AS NVARCHAR(30)));
        THROW 50036, @Msg, 1;
    END
END;
GO

DECLARE @TriggerCount INT =
(
    SELECT COUNT(*) FROM sys.triggers WHERE is_ms_shipped = 0
);
PRINT 'Triggers created: ' + CAST(@TriggerCount AS VARCHAR(10)) + ' (expected 3)';
GO
