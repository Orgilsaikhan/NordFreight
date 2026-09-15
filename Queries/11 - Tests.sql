/*
  NordFreight Logistics -- 11 - Тестүүд
  Датабаазын автомат тестүүд, жишээ датаны дараа ажиллуулна. Тест бүр тусдаа batch (GO).
  Дата өөрчилдөг тест rollback хийгдэж, үр дүнг rollback-ийн ДАРАА #TestResults-д бичнэ.
  Аль нэг тест унавал төгсгөлд THROW хийнэ, тэгэхээр `sqlcmd -b` алдаатай гарна.
  Хэсэг: 1 PK T01-T03, 2 FK T04-T08, 3 UNIQUE T09-T14, 4 CHECK T15-T22, 5 insert T23-T26,
  6 транзакц T27-T30, 7 procedure T31-T47, 8 trigger T48-T55, 9 функц T56-T59, 10 дата T60-T79, 11 T80.
  Алдааны дугаар: 515 NULL, 547 FK/CHECK, 2601/2627 давхардал, 220 overflow, 241 огноо, 2628 урт, 500xx процедур.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* Тестийн туслах объектууд */

IF OBJECT_ID('tempdb..#TestResults') IS NOT NULL DROP TABLE #TestResults;
CREATE TABLE #TestResults
(
    TestNo   INT            IDENTITY(1,1) PRIMARY KEY,
    Category NVARCHAR(40)   NOT NULL,
    TestName NVARCHAR(200)  NOT NULL,
    Passed   BIT            NOT NULL,
    Detail   NVARCHAR(2000) NULL
);
GO

IF OBJECT_ID('tempdb..#RecordResult') IS NOT NULL DROP PROCEDURE #RecordResult;
GO
CREATE PROCEDURE #RecordResult
    @Category NVARCHAR(40),
    @TestName NVARCHAR(200),
    @Passed   BIT,
    @Detail   NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Транзакц нээлттэй орхисон тест дараагийн үр дүнгүүдийг залгичихна, тиймээс fail гэж тооцно.
    IF @@TRANCOUNT > 0
    BEGIN
        SET @Passed = 0;
        SET @Detail = N'TEST LEFT A TRANSACTION OPEN. ' + ISNULL(@Detail, N'');
    END

    INSERT INTO #TestResults (Category, TestName, Passed, Detail)
    VALUES (@Category, @TestName, ISNULL(@Passed, 0), @Detail);

    PRINT CASE WHEN ISNULL(@Passed, 0) = 1 THEN N'  PASS  ' ELSE N'  FAIL  ' END
        + @TestName
        + CASE WHEN ISNULL(@Passed, 0) = 0 THEN N'  -->  ' + ISNULL(@Detail, N'') ELSE N'' END;
END;
GO

-- Бүрэн бүтэн байдлын шалгалтад туслах: зөрчил 0 бол тэнцэнэ.
IF OBJECT_ID('tempdb..#AssertZero') IS NOT NULL DROP PROCEDURE #AssertZero;
GO
CREATE PROCEDURE #AssertZero
    @TestName   NVARCHAR(200),
    @Violations INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Passed BIT = CASE WHEN @Violations = 0 THEN 1 ELSE 0 END;
    DECLARE @Detail NVARCHAR(200) = CONCAT(@Violations, N' violating row(s)');
    EXEC #RecordResult N'Data integrity', @TestName, @Passed, @Detail;
END;
GO

-- Мөрийн тоо, checksum-ийн snapshot; T80 төгсгөлд дахин харьцуулна.
IF OBJECT_ID('tempdb..#Baseline') IS NOT NULL DROP TABLE #Baseline;
SELECT 'Shipments' AS TableName, COUNT_BIG(*) AS RowCnt,
       CHECKSUM_AGG(CHECKSUM(ShipmentId, Status, ActualDeliveryDate, IsInsured)) AS Chk
INTO #Baseline FROM dbo.Shipments
UNION ALL SELECT 'ShipmentItems',         COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(ShipmentItemId))       FROM dbo.ShipmentItems
UNION ALL SELECT 'ShipmentStatusHistory', COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(StatusHistoryId, Notes)) FROM dbo.ShipmentStatusHistory
UNION ALL SELECT 'Trips',                 COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(TripId, Status, ActualArrival)) FROM dbo.Trips
UNION ALL SELECT 'TripDrivers',           COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(TripId, DriverId))     FROM dbo.TripDrivers
UNION ALL SELECT 'TripShipments',         COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(TripId, ShipmentId))   FROM dbo.TripShipments
UNION ALL SELECT 'Invoices',              COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(InvoiceId, Status))    FROM dbo.Invoices
UNION ALL SELECT 'InvoiceLines',          COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(InvoiceLineId))        FROM dbo.InvoiceLines
UNION ALL SELECT 'Payments',              COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(PaymentId, Amount))    FROM dbo.Payments
UNION ALL SELECT 'Customers',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(CustomerId, CreditLimit, TaxNumber)) FROM dbo.Customers
UNION ALL SELECT 'CustomerContacts',      COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(ContactId, IsPrimary)) FROM dbo.CustomerContacts
UNION ALL SELECT 'Countries',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(CountryId))            FROM dbo.Countries
UNION ALL SELECT 'Employees',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(EmployeeId, ManagerId)) FROM dbo.Employees
UNION ALL SELECT 'Drivers',               COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(DriverId, LicenceExpiresOn)) FROM dbo.Drivers
UNION ALL SELECT 'Vehicles',              COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(VehicleId, Status, VIN)) FROM dbo.Vehicles
UNION ALL SELECT 'Lanes',                 COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(LaneId))               FROM dbo.Lanes
UNION ALL SELECT 'LaneRates',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(LaneRateId))           FROM dbo.LaneRates;
GO

PRINT '';
PRINT '=== 1. Primary key constraints ===';
GO

/* 1-р хэсэг - Үндсэн түлхүүр (PK) */

-- T01: TripDrivers-ийн нийлмэл PK нэг жолоочийг нэг рейст хоёр удаа оноохгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.TripDrivers (TripId, DriverId, DriverRole)
    SELECT TOP (1) TripId, DriverId, N'CoDriver'
    FROM dbo.TripDrivers
    ORDER BY TripId;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2627 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Primary key', N'T01 Duplicate (TripId, DriverId) in TripDrivers is rejected', @Passed, @Detail;
GO

-- T02: ONE-TO-ONE: Drivers.DriverId нь PK тул нэг ажилтанд хоёр жолоочийн профайл байхгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Drivers (DriverId, LicenceNumber, LicenceClass, LicenceIssuedOn,
                             LicenceExpiresOn, MedicalCertExpiresOn)
    VALUES (17, N'EE-DL-SECOND-PROFILE', 'C', '2020-01-01', '2030-01-01', '2030-01-01');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2627 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Primary key', N'T02 One-to-one: a second driver profile for the same employee is rejected', @Passed, @Detail;
GO

-- T03: үндсэн түлхүүрийн багана хэзээ ч NULL байж болохгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.TripShipments (TripId, ShipmentId, StopSequence, LegType)
    VALUES (NULL, 1, 1, N'LineHaul');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 515 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Primary key', N'T03 NULL in a primary key column is rejected', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 2. Foreign key constraints ===';
GO

/* 2-р хэсэг - Гадаад түлхүүр (FK) */

-- T04: ачаа нь байхгүй харилцагч руу заах ёсгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Shipments
        (TrackingNumber, CustomerId, LaneId, ServiceLevelId, CargoCategoryId,
         OriginAddressId, DestinationAddressId, PickupDate, PromisedDeliveryDate,
         TotalWeightKg, TotalVolumeM3, FreightCharge)
    VALUES
        (N'NF99999999', 999999, 1, 2, 1, 20, 24,
         CAST(SYSUTCDATETIME() AS DATE), DATEADD(DAY, 4, CAST(SYSUTCDATETIME() AS DATE)),
         100, 1, 50);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Foreign key', N'T04 Shipment for a non-existent customer is rejected', @Passed, @Detail;
GO

-- T05: NO ACTION түүхийг хамгаална - ачаатай харилцагчийг устгаж болохгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.Customers WHERE CustomerId = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Foreign key', N'T05 Deleting a customer that has shipments is blocked (NO ACTION)', @Passed, @Detail;
GO

-- T06: рейсээр явсан ачааг устгаж болохгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @ShipmentId BIGINT =
(
    SELECT TOP (1) ts.ShipmentId
    FROM dbo.TripShipments AS ts
    WHERE NOT EXISTS (SELECT 1 FROM dbo.InvoiceLines il WHERE il.ShipmentId = ts.ShipmentId)
    ORDER BY ts.ShipmentId
);
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.Shipments WHERE ShipmentId = @ShipmentId;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%FK_TripShipments_Shipments%'
                          THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Foreign key', N'T06 Deleting a shipment that is on a trip manifest is blocked', @Passed, @Detail;
GO

-- T07: харилцагч устахад холбоо барих хүмүүс нь CASCADE-аар хамт устна.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Customers (CustomerCode, LegalName, TaxNumber, BillingAddressId, OnboardedOn)
    VALUES (N'CUS-9999', N'Cascade Test Ltd', N'TEST-CASCADE-001', 8, CAST(SYSUTCDATETIME() AS DATE));
    DECLARE @CustomerId INT = SCOPE_IDENTITY();

    INSERT INTO dbo.CustomerContacts (CustomerId, FullName, Email, IsPrimary) VALUES
        (@CustomerId, N'Test Contact One', N'one@cascade.example', 1),
        (@CustomerId, N'Test Contact Two', N'two@cascade.example', 0);

    DECLARE @Before INT = (SELECT COUNT(*) FROM dbo.CustomerContacts WHERE CustomerId = @CustomerId);
    DELETE FROM dbo.Customers WHERE CustomerId = @CustomerId;
    DECLARE @After  INT = (SELECT COUNT(*) FROM dbo.CustomerContacts WHERE CustomerId = @CustomerId);

    IF @Before = 2 AND @After = 0 SET @Passed = 1;
    SET @Detail = CONCAT(N'Contacts before delete: ', @Before, N', after: ', @After);

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = 0, @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Foreign key', N'T07 Deleting a customer cascades to its contacts', @Passed, @Detail;
GO

-- T08: рейс устахад жолооч нар, ачааны жагсаалт нь CASCADE-аар хамт устна.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @TripId INT =
(
    SELECT TOP (1) t.TripId
    FROM dbo.Trips AS t
    WHERE EXISTS (SELECT 1 FROM dbo.TripShipments ts WHERE ts.TripId = t.TripId)
      AND EXISTS (SELECT 1 FROM dbo.TripDrivers   td WHERE td.TripId = t.TripId)
    ORDER BY t.TripId
);
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.Trips WHERE TripId = @TripId;

    DECLARE @Crew     INT = (SELECT COUNT(*) FROM dbo.TripDrivers   WHERE TripId = @TripId);
    DECLARE @Manifest INT = (SELECT COUNT(*) FROM dbo.TripShipments WHERE TripId = @TripId);

    IF @TripId IS NOT NULL AND @Crew = 0 AND @Manifest = 0 SET @Passed = 1;
    SET @Detail = CONCAT(N'Trip ', @TripId, N': crew rows left ', @Crew, N', manifest rows left ', @Manifest);

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = 0, @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Foreign key', N'T08 Deleting a trip cascades to TripDrivers and TripShipments', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 3. UNIQUE constraints and indexes ===';
GO

/* 3-р хэсэг - UNIQUE хязгаарлалт ба шүүлтүүртэй индекс */

-- T09: татварын дугаар давхардахгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Customers (CustomerCode, LegalName, TaxNumber, BillingAddressId, OnboardedOn)
    SELECT N'CUS-9998', N'Duplicate Tax Number Ltd', TaxNumber, 8, CAST(SYSUTCDATETIME() AS DATE)
    FROM dbo.Customers WHERE CustomerId = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2627 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Unique', N'T09 Duplicate customer tax number is rejected', @Passed, @Detail;
GO

-- T10: шүүлтүүртэй unique индекс - нэг харилцагчид нэг л PRIMARY холбоо барих хүн.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.CustomerContacts (CustomerId, FullName, Email, IsPrimary)
    VALUES (1, N'Second Primary', N'second.primary@baltibuild.example', 1);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2601
                           AND ERROR_MESSAGE() LIKE N'%UX_CustomerContacts_OnePrimary%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Unique', N'T10 A second primary contact for the same customer is rejected', @Passed, @Detail;
GO

-- T10b: харин primary биш холбоо барих хүн хэдэн ч байж болно.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.CustomerContacts (CustomerId, FullName, Email, IsPrimary) VALUES
        (1, N'Extra Contact A', N'extra.a@baltibuild.example', 0),
        (1, N'Extra Contact B', N'extra.b@baltibuild.example', 0);
    SET @Passed = 1;
    SET @Detail = N'Two additional non-primary contacts accepted.';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = 0, @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Unique', N'T10b Additional non-primary contacts are still allowed', @Passed, @Detail;
GO

-- T11: шүүлтүүртэй unique индекс - нэг рейст нэг л Primary жолооч.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @TripId INT = (SELECT TOP (1) TripId FROM dbo.TripDrivers WHERE DriverRole = N'Primary' ORDER BY TripId);
DECLARE @DriverId INT =
(
    SELECT TOP (1) d.DriverId
    FROM dbo.Drivers AS d
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TripDrivers td WHERE td.TripId = @TripId AND td.DriverId = d.DriverId)
    ORDER BY d.DriverId
);
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.TripDrivers (TripId, DriverId, DriverRole) VALUES (@TripId, @DriverId, N'Primary');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2601
                           AND ERROR_MESSAGE() LIKE N'%UX_TripDrivers_OnePrimary%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Unique', N'T11 A second Primary driver on the same trip is rejected', @Passed, @Detail;
GO

-- T12: ГОЛ БИЗНЕС ДҮРЭМ - нэг ачааг хэзээ ч хоёр удаа нэхэмжилж болохгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.InvoiceLines (InvoiceId, ShipmentId, LineNumber, Description, NetAmount)
    SELECT TOP (1) other.InvoiceId, il.ShipmentId, 999, N'Duplicate billing attempt', il.NetAmount
    FROM dbo.InvoiceLines AS il
    CROSS APPLY (SELECT TOP (1) i.InvoiceId FROM dbo.Invoices i
                 WHERE i.InvoiceId <> il.InvoiceId ORDER BY i.InvoiceId) AS other
    ORDER BY il.InvoiceLineId;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2627
                           AND ERROR_MESSAGE() LIKE N'%UQ_InvoiceLines_Shipment%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Unique', N'T12 Billing an already-invoiced shipment on another invoice is rejected', @Passed, @Detail;
GO

-- T13: нэг чиглэл+үйлчилгээнд дуусах огноогүй (одоогийн) тариф нэг л байна.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.LaneRates (LaneId, ServiceLevelId, RatePerKg, MinimumCharge, EffectiveFrom, EffectiveTo)
    VALUES (1, 1, 0.5000, 100.00, DATEADD(DAY, 30, CAST(SYSUTCDATETIME() AS DATE)), NULL);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2601
                           AND ERROR_MESSAGE() LIKE N'%UX_LaneRates_OneCurrentRate%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Unique', N'T13 A second open-ended rate for the same lane and service is rejected', @Passed, @Detail;
GO

-- T14: tracking дугаар давхардахгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Shipments
    SET TrackingNumber = (SELECT TrackingNumber FROM dbo.Shipments WHERE ShipmentId = 1)
    WHERE ShipmentId = 2;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 2627 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Unique', N'T14 Duplicate tracking number is rejected', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 4. CHECK constraints ===';
GO

/* 4-р хэсэг - CHECK хязгаарлалт */

-- T15
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Customers SET CreditLimit = -1 WHERE CustomerId = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Customers_CreditLimit%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T15 Negative credit limit is rejected', @Passed, @Detail;
GO

-- T16
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Lanes (OriginTerminalId, DestinationTerminalId, DistanceKm, EstimatedDrivingHours)
    VALUES (3, 3, 10.00, 0.50);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Lanes_DistinctTerminals%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T16 A lane from a terminal to itself is rejected', @Passed, @Detail;
GO

-- T17: нэг цагт 1,000 km гэдэг ачааны машинд боломжгүй хурд.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Lanes (OriginTerminalId, DestinationTerminalId, DistanceKm, EstimatedDrivingHours)
    VALUES (1, 7, 1000.00, 1.00);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Lanes_PlausibleSpeed%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T17 A lane with an implausible average speed is rejected', @Passed, @Detail;
GO

-- T18
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Shipments
    SET Status = N'Delivered'           -- ActualDeliveryDate нь NULL хэвээр
    WHERE ShipmentId = (SELECT TOP (1) ShipmentId FROM dbo.Shipments WHERE Status = N'Booked' ORDER BY ShipmentId);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Shipments_DeliveredHasDate%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T18 A Delivered shipment without a delivery date is rejected', @Passed, @Detail;
GO

-- T19: VIN дугаарт I, O, Q үсэг хэзээ ч ордоггүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Vehicles SET VIN = 'WMA06XZZ4NM73482O' WHERE VehicleId = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Vehicles_VIN%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T19 A VIN containing the letter O is rejected', @Passed, @Detail;
GO

-- T20
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Employees SET ManagerId = EmployeeId WHERE EmployeeId = 5;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Employees_NotOwnManager%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T20 An employee cannot be their own manager', @Passed, @Detail;
GO

-- T21
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Shipments SET Status = N'Lost' WHERE ShipmentId = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Shipments_Status%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T21 An unknown shipment status is rejected', @Passed, @Detail;
GO

-- T22
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Trips
    SET ActualArrival = NULL
    WHERE TripId = (SELECT TOP (1) TripId FROM dbo.Trips WHERE Status = N'Completed' ORDER BY TripId);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 547 AND ERROR_MESSAGE() LIKE N'%CK_Trips_CompletedHasActuals%' THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Check', N'T22 A Completed trip without an actual arrival time is rejected', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 5. Invalid inserts ===';
GO

/* 5-р хэсэг - Буруу insert (NOT NULL, төрөл, хэмжээ) */

-- T23
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Customers (CustomerCode, LegalName, TaxNumber, BillingAddressId, OnboardedOn)
    VALUES (N'CUS-9997', NULL, N'TEST-NULL-001', 8, CAST(SYSUTCDATETIME() AS DATE));
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 515 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Invalid insert', N'T23 NULL into a NOT NULL column is rejected', @Passed, @Detail;
GO

-- T24: AxleCount нь TINYINT (0-255).
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.VehicleTypes (TypeCode, TypeName, MaxPayloadKg, MaxVolumeM3, AxleCount, RequiredLicenceClass)
    VALUES (N'TEST', N'Overflow Test', 1000, 10, 300, 'C');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 220 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Invalid insert', N'T24 A value too large for TINYINT is rejected', @Passed, @Detail;
GO

-- T25: 2-р сарын 30 гэж өдөр байдаггүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Drivers SET LicenceExpiresOn = '2030-02-30' WHERE DriverId = 17;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 241 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Invalid insert', N'T25 An impossible date is rejected', @Passed, @Detail;
GO

-- T26: IsoCode нь CHAR(2).
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Countries (IsoCode, CountryName, CurrencyCode) VALUES ('SWE', N'Sweden', 'SEK');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() IN (2628, 8152) THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Invalid insert', N'T26 A string longer than the column is rejected, not silently truncated', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 6. Transactions and rollback ===';
GO

/* 6-р хэсэг - Транзакц ба rollback */

-- T27: XACT_ABORT ON үед нэг алдаа БҮТЭН транзакцыг буцааж, өмнөх зөв insert ч rollback болно.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000), @State SMALLINT = NULL;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Countries (IsoCode, CountryName, CurrencyCode) VALUES ('SE', N'Sweden', 'SEK');
    INSERT INTO dbo.Countries (IsoCode, CountryName, CurrencyCode) VALUES ('EE', N'Estonia Again', 'EUR');  -- давхардсан
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SET @State = XACT_STATE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
SET XACT_ABORT OFF;

IF @State = -1 AND NOT EXISTS (SELECT 1 FROM dbo.Countries WHERE IsoCode = 'SE') SET @Passed = 1;
SET @Detail = CONCAT(N'XACT_STATE in CATCH: ', @State,
                     N'; Sweden persisted: ', (SELECT COUNT(*) FROM dbo.Countries WHERE IsoCode = 'SE'));
EXEC #RecordResult N'Transaction', N'T27 XACT_ABORT ON: a failure rolls back the earlier successful insert', @Passed, @Detail;
GO

-- T28: урхи. XACT_ABORT OFF үед алдаа зөвхөн STATEMENT-ийг зогсоож, транзакц амьд үлдэнэ.
-- Энд COMMIT хийвэл ажлын тал нь хадгалагдана - тиймээс бүх procedure XACT_ABORT ON ашигладаг.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000), @State SMALLINT = NULL, @Visible INT = NULL;
SET XACT_ABORT OFF;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Countries (IsoCode, CountryName, CurrencyCode) VALUES ('SE', N'Sweden', 'SEK');
    INSERT INTO dbo.Countries (IsoCode, CountryName, CurrencyCode) VALUES ('EE', N'Estonia Again', 'EUR');  -- давхардсан
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SET @State   = XACT_STATE();
    SET @Visible = (SELECT COUNT(*) FROM dbo.Countries WHERE IsoCode = 'SE');
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @State = 1 AND @Visible = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Countries WHERE IsoCode = 'SE')
    SET @Passed = 1;
SET @Detail = CONCAT(N'XACT_STATE in CATCH: ', @State, N'; Sweden visible inside the open transaction: ', @Visible);
EXEC #RecordResult N'Transaction', N'T28 XACT_ABORT OFF: the transaction survives a constraint error (the pitfall)', @Passed, @Detail;
GO

-- T29: savepoint транзакцын зөвхөн нэг хэсгийг rollback хийнэ.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000), @SE INT, @NO INT, @TranCount INT;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Countries (IsoCode, CountryName, CurrencyCode) VALUES ('SE', N'Sweden', 'SEK');

    SAVE TRANSACTION BeforeNorway;
    INSERT INTO dbo.Countries (IsoCode, CountryName, CurrencyCode) VALUES ('NO', N'Norway', 'NOK');
    ROLLBACK TRANSACTION BeforeNorway;          -- зөвхөн Норвегийг буцаана

    SELECT @SE = COUNT(*) FROM dbo.Countries WHERE IsoCode = 'SE';
    SELECT @NO = COUNT(*) FROM dbo.Countries WHERE IsoCode = 'NO';
    SET @TranCount = @@TRANCOUNT;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @SE = 1 AND @NO = 0 AND @TranCount = 1 SET @Passed = 1;
SET @Detail = ISNULL(@Detail, CONCAT(N'Sweden: ', @SE, N', Norway: ', @NO, N', @@TRANCOUNT after partial rollback: ', @TranCount));
EXEC #RecordResult N'Transaction', N'T29 SAVE TRANSACTION allows a partial rollback', @Passed, @Detail;
GO

-- T30: бараа CHECK-д унавал procedure аль хэдийн орсон ачаа, audit мөрийг ч rollback хийнэ.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.', @ErrNo INT = NULL;
DECLARE @ShipmentsBefore INT = (SELECT COUNT(*) FROM dbo.Shipments);
DECLARE @HistoryBefore   INT = (SELECT COUNT(*) FROM dbo.ShipmentStatusHistory);
DECLARE @Items dbo.ShipmentItemList;
INSERT INTO @Items (LineNumber, Description, Quantity, UnitWeightKg, UnitVolumeM3, PackagingType)
VALUES (1, N'Barrels (not an allowed packaging type)', 2, 50.000, 0.2000, N'Barrel');

BEGIN TRY
    EXEC dbo.usp_CreateShipment
         @CustomerId = 1, @LaneId = 1, @ServiceLevelId = 2, @CargoCategoryId = 1,
         @OriginAddressId = 20, @DestinationAddressId = 24, @Items = @Items;
END TRY
BEGIN CATCH
    SELECT @ErrNo = ERROR_NUMBER(),
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

DECLARE @ShipmentsAfter INT = (SELECT COUNT(*) FROM dbo.Shipments);
DECLARE @HistoryAfter   INT = (SELECT COUNT(*) FROM dbo.ShipmentStatusHistory);
IF @ErrNo = 547 AND @ShipmentsAfter = @ShipmentsBefore AND @HistoryAfter = @HistoryBefore SET @Passed = 1;
SET @Detail = CONCAT(@Detail, N' | shipments ', @ShipmentsBefore, N'->', @ShipmentsAfter,
                     N', history ', @HistoryBefore, N'->', @HistoryAfter);
EXEC #RecordResult N'Transaction', N'T30 usp_CreateShipment rolls back the shipment when an item fails', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 7. Stored procedure behaviour ===';
GO

/* 7-р хэсэг - Stored procedure-ийн ажиллагаа
   Happy path тестүүд гаднах транзакцад ажиллаж rollback хийгдэнэ (дотрох COMMIT зөвхөн @@TRANCOUNT бууруулна).
   Үр дүнг INSERT ... EXEC-ээр table variable-д авна, учир нь ROLLBACK түүнд нөлөөлдөггүй. */

-- T31: usp_CreateShipment-ийн happy path
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
DECLARE @Items dbo.ShipmentItemList;
INSERT INTO @Items (LineNumber, Description, Quantity, UnitWeightKg, UnitVolumeM3, PackagingType) VALUES
    (1, N'Test pallets', 4, 150.000, 1.2000, N'Pallet'),     -- 600 kg
    (2, N'Test cartons', 10, 12.500, 0.0800, N'Box');        -- 125 kg
DECLARE @Out TABLE (ShipmentId BIGINT, TrackingNumber NVARCHAR(20), TotalWeightKg DECIMAL(10,2),
                    FreightCharge DECIMAL(12,2), SurchargeAmount DECIMAL(12,2),
                    TaxAmount DECIMAL(12,2), TotalAmount DECIMAL(12,2));
DECLARE @NewId BIGINT, @NewTracking NVARCHAR(20),
        @Weight DECIMAL(10,2), @Total DECIMAL(12,2), @Status NVARCHAR(20), @Promised DATE,
        @ItemCount INT, @Quote DECIMAL(12,2), @History INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO @Out
    EXEC dbo.usp_CreateShipment
         @CustomerId = 1, @LaneId = 1, @ServiceLevelId = 2, @CargoCategoryId = 1,
         @OriginAddressId = 20, @DestinationAddressId = 24, @Items = @Items,
         @ShipmentId = @NewId OUTPUT, @TrackingNumber = @NewTracking OUTPUT;

    SELECT @Weight = TotalWeightKg, @Total = TotalAmount, @Status = Status, @Promised = PromisedDeliveryDate
    FROM dbo.Shipments WHERE ShipmentId = @NewId;

    SET @ItemCount = (SELECT COUNT(*) FROM dbo.ShipmentItems WHERE ShipmentId = @NewId);
    SET @Quote     = (SELECT TotalAmount FROM dbo.fn_QuoteShipment(1, 2, 1, 725.00, @Today));
    SET @History   = (SELECT COUNT(*) FROM dbo.ShipmentStatusHistory
                      WHERE ShipmentId = @NewId AND OldStatus IS NULL AND NewStatus = N'Booked');

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @Detail IS NULL
BEGIN
    IF @NewTracking LIKE N'NF[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
       AND @Weight = 725.00 AND @ItemCount = 2 AND @Status = N'Booked'
       AND @Promised = DATEADD(DAY, 4, @Today)       -- Standard = 4 хоног
       AND @Total = @Quote AND @History = 1
        SET @Passed = 1;
    SET @Detail = CONCAT(N'Tracking ', @NewTracking, N', weight ', @Weight, N', items ', @ItemCount,
                         N', status ', @Status, N', total ', @Total, N' vs quote ', @Quote,
                         N', opening history rows ', @History);
END
EXEC #RecordResult N'Procedure', N'T31 usp_CreateShipment books, weighs, prices and audits a shipment', @Passed, @Detail;
GO

-- T32: идэвхгүй харилцагч ачаа захиалж чадахгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Items dbo.ShipmentItemList;
INSERT INTO @Items VALUES (1, N'Box', 1, 10.000, 0.1000, N'Box');
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_CreateShipment
         @CustomerId = 12, @LaneId = 1, @ServiceLevelId = 2, @CargoCategoryId = 1,
         @OriginAddressId = 20, @DestinationAddressId = 24, @Items = @Items;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50011 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T32 usp_CreateShipment refuses an inactive customer (50011)', @Passed, @Detail;
GO

-- T33: зээлийн хяналт. 999 тонн ачаа 60,000-ийн лимитийг шууд давчихна.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Items dbo.ShipmentItemList;
INSERT INTO @Items VALUES (1, N'Steel coils', 1000, 999.000, 0.5000, N'Roll');
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_CreateShipment
         @CustomerId = 9, @LaneId = 9, @ServiceLevelId = 2, @CargoCategoryId = 1,
         @OriginAddressId = 32, @DestinationAddressId = 34, @Items = @Items;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50019 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T33 usp_CreateShipment refuses a booking over the credit limit (50019)', @Passed, @Detail;
GO

-- T34: бараагүй (item-гүй) ачааг хүлээж авахгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Items dbo.ShipmentItemList;       -- санаатайгаар хоосон
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_CreateShipment
         @CustomerId = 1, @LaneId = 1, @ServiceLevelId = 2, @CargoCategoryId = 1,
         @OriginAddressId = 20, @DestinationAddressId = 24, @Items = @Items;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50010 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T34 usp_CreateShipment refuses an empty item list (50010)', @Passed, @Detail;
GO

-- T35: зөв төлөвийн шилжилт; тэмдэглэл, терминал нь trigger-ийн audit мөрөнд бичигдэнэ.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @ShipmentId BIGINT = (SELECT TOP (1) ShipmentId FROM dbo.Shipments WHERE Status = N'PickedUp' ORDER BY ShipmentId);
DECLARE @Out TABLE (ShipmentId BIGINT, PreviousStatus NVARCHAR(20), CurrentStatus NVARCHAR(20));
DECLARE @NewStatus NVARCHAR(20), @OldH NVARCHAR(20), @NewH NVARCHAR(20), @NoteH NVARCHAR(400), @TermH INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO @Out
    EXEC dbo.usp_UpdateShipmentStatus
         @ShipmentId = @ShipmentId, @NewStatus = N'InTransit',
         @TerminalId = 1, @Notes = N'Loaded at Tallinn, departed on schedule';

    SET @NewStatus = (SELECT Status FROM dbo.Shipments WHERE ShipmentId = @ShipmentId);
    SELECT TOP (1) @OldH = OldStatus, @NewH = NewStatus, @NoteH = Notes, @TermH = TerminalId
    FROM dbo.ShipmentStatusHistory
    WHERE ShipmentId = @ShipmentId
    ORDER BY StatusHistoryId DESC;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @Detail IS NULL
BEGIN
    IF @ShipmentId IS NOT NULL AND @NewStatus = N'InTransit' AND @OldH = N'PickedUp'
       AND @NewH = N'InTransit' AND @NoteH LIKE N'Loaded at Tallinn%' AND @TermH = 1
        SET @Passed = 1;
    SET @Detail = CONCAT(N'Shipment ', @ShipmentId, N' now ', @NewStatus, N'; audit ', @OldH, N'->', @NewH,
                         N', terminal ', @TermH, N', note "', @NoteH, N'"');
END
EXEC #RecordResult N'Procedure', N'T35 usp_UpdateShipmentStatus applies a legal transition and enriches the audit row', @Passed, @Detail;
GO

-- T36: state machine ачааг буцааш нь шилжүүлэхийг зөвшөөрдөггүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @ShipmentId BIGINT = (SELECT TOP (1) ShipmentId FROM dbo.Shipments WHERE Status = N'Delivered' ORDER BY ShipmentId);
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_UpdateShipmentStatus @ShipmentId = @ShipmentId, @NewStatus = N'InTransit';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50022 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T36 usp_UpdateShipmentStatus refuses Delivered -> InTransit (50022)', @Passed, @Detail;
GO

-- T37: хүргэсэн огноо ачаа авсан огнооноос өмнө байж болохгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @ShipmentId BIGINT, @PickupDate DATE, @BadDate DATE;
SELECT TOP (1) @ShipmentId = ShipmentId, @PickupDate = PickupDate
FROM dbo.Shipments WHERE Status = N'OutForDelivery' ORDER BY ShipmentId;
SET @BadDate = DATEADD(DAY, -1, @PickupDate);
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_UpdateShipmentStatus @ShipmentId = @ShipmentId, @NewStatus = N'Delivered',
                                      @ActualDeliveryDate = @BadDate;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50023 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T37 usp_UpdateShipmentStatus refuses a delivery date before pickup (50023)', @Passed, @Detail;
GO

-- T38: usp_DispatchTrip-ийн happy path - нэг транзакцад зургаан хүснэгт.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT TOP (2) s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = 1 AND cc.RequiresRefrigeration = 0
ORDER BY s.PickupDate, s.ShipmentId;

DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 6, CAST(DATEADD(DAY, 1, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(0)));
DECLARE @Out TABLE (TripId INT, TripNumber NVARCHAR(20), LoadWeightKg DECIMAL(12,2),
                    VehiclePayloadKg DECIMAL(10,2), PayloadUtilisationPct DECIMAL(5,2), ShipmentsLoaded INT);
DECLARE @TripId INT, @TripStatus NVARCHAR(20), @Crew INT, @Primaries INT, @Manifest INT,
        @VehicleStatus NVARCHAR(20), @InTransit INT, @Audited INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO @Out
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1, @OriginTerminalId = 1, @DestinationTerminalId = 2,
         @PrimaryDriverId = 17, @CoDriverId = 20,
         @ScheduledDeparture = @Departure, @ShipmentIds = @Ids, @TripId = @TripId OUTPUT;

    SET @TripStatus    = (SELECT Status FROM dbo.Trips WHERE TripId = @TripId);
    SET @Crew          = (SELECT COUNT(*) FROM dbo.TripDrivers WHERE TripId = @TripId);
    SET @Primaries     = (SELECT COUNT(*) FROM dbo.TripDrivers WHERE TripId = @TripId AND DriverRole = N'Primary');
    SET @Manifest      = (SELECT COUNT(*) FROM dbo.TripShipments WHERE TripId = @TripId);
    SET @VehicleStatus = (SELECT Status FROM dbo.Vehicles WHERE VehicleId = 1);
    SET @InTransit     = (SELECT COUNT(*) FROM dbo.Shipments s INNER JOIN @Ids i ON i.Id = s.ShipmentId
                          WHERE s.Status = N'InTransit');
    SET @Audited       = (SELECT COUNT(*) FROM dbo.ShipmentStatusHistory h INNER JOIN @Ids i ON i.Id = h.ShipmentId
                          WHERE h.OldStatus = N'Booked' AND h.NewStatus = N'InTransit');

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @Detail IS NULL
BEGIN
    IF (SELECT COUNT(*) FROM @Ids) = 2 AND @TripStatus = N'Dispatched' AND @Crew = 2 AND @Primaries = 1
       AND @Manifest = 2 AND @VehicleStatus = N'OnTrip' AND @InTransit = 2 AND @Audited = 2
        SET @Passed = 1;
    SET @Detail = CONCAT(N'Trip ', (SELECT TripNumber FROM @Out), N' status ', @TripStatus,
                         N'; crew ', @Crew, N' (primary ', @Primaries, N'); manifest ', @Manifest,
                         N'; vehicle ', @VehicleStatus, N'; shipments in transit ', @InTransit,
                         N'; audit rows ', @Audited);
END
EXEC #RecordResult N'Procedure', N'T38 usp_DispatchTrip creates trip, crew, manifest and moves statuses', @Passed, @Detail;
GO

-- T39: үнэмлэх нь дууссан, ажлаас гарсан жолоочийг рейст оноохгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT TOP (1) s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = 1 AND cc.RequiresRefrigeration = 0
ORDER BY s.ShipmentId;
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1, @OriginTerminalId = 1, @DestinationTerminalId = 2,
         @PrimaryDriverId = 32, @ScheduledDeparture = @Departure, @ShipmentIds = @Ids;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50031 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T39 usp_DispatchTrip refuses a driver with an expired licence (50031)', @Passed, @Detail;
GO

-- T40: 3.5 t даацтай rigid машинд хэт их ачаа ачих.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @LaneId INT =
(
    SELECT TOP (1) s.LaneId
    FROM dbo.Shipments AS s
    INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
    WHERE s.Status = N'Booked' AND cc.RequiresRefrigeration = 0
    GROUP BY s.LaneId
    HAVING SUM(s.TotalWeightKg) > 3500
    ORDER BY SUM(s.TotalWeightKg) DESC
);
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = @LaneId AND cc.RequiresRefrigeration = 0;
DECLARE @Origin INT, @Destination INT;
SELECT @Origin = OriginTerminalId, @Destination = DestinationTerminalId FROM dbo.Lanes WHERE LaneId = @LaneId;
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 15,                         -- RIG75: 3,500 kg даац
         @OriginTerminalId = @Origin, @DestinationTerminalId = @Destination,
         @PrimaryDriverId = 18, @ScheduledDeparture = @Departure, @ShipmentIds = @Ids;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50034 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T40 usp_DispatchTrip refuses a load heavier than the vehicle payload (50034)', @Passed, @Detail;
GO

-- T41: хөргүүр шаардлагатай ачааг curtainsider (тентэй) машинд ачих.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @ShipmentId BIGINT, @Origin INT, @Destination INT;
SELECT TOP (1) @ShipmentId = s.ShipmentId, @Origin = l.OriginTerminalId, @Destination = l.DestinationTerminalId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
INNER JOIN dbo.Lanes           AS l  ON l.LaneId           = s.LaneId
WHERE s.Status = N'Booked' AND cc.RequiresRefrigeration = 1
ORDER BY s.ShipmentId;
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id) VALUES (@ShipmentId);
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1,                          -- ARTIC: хөргүүргүй
         @OriginTerminalId = @Origin, @DestinationTerminalId = @Destination,
         @PrimaryDriverId = 17, @ScheduledDeparture = @Departure, @ShipmentIds = @Ids;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50035 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T41 usp_DispatchTrip refuses chilled cargo on a non-refrigerated vehicle (50035)', @Passed, @Detail;
GO

-- T42: Варшав -> Гданьск ачааг Таллин -> Рига явах машинд ачих.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT TOP (1) s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = 9 AND cc.RequiresRefrigeration = 0
ORDER BY s.ShipmentId;
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1, @OriginTerminalId = 1, @DestinationTerminalId = 2,
         @PrimaryDriverId = 17, @ScheduledDeparture = @Departure, @ShipmentIds = @Ids;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50037 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T42 usp_DispatchTrip refuses a shipment that is not on the trip route (50037)', @Passed, @Detail;
GO

-- T43: нэхэмжлэх үүсгээд, ижил хугацаагаар дахин ажиллуулахад нэхэмжлэх юм олдох ёсгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
DECLARE @CustomerId INT, @ExpectedLines INT, @ExpectedNet DECIMAL(12,2);

SELECT TOP (1) @CustomerId = s.CustomerId, @ExpectedLines = COUNT(*),
               @ExpectedNet = SUM(s.FreightCharge + s.SurchargeAmount)
FROM dbo.Shipments AS s
WHERE s.Status = N'Delivered'
  AND s.ActualDeliveryDate <= @Today
  AND NOT EXISTS (SELECT 1 FROM dbo.InvoiceLines il WHERE il.ShipmentId = s.ShipmentId)
GROUP BY s.CustomerId
ORDER BY COUNT(*) DESC;

DECLARE @Out TABLE (InvoiceId INT, InvoiceNumber NVARCHAR(20), CustomerId INT, IssueDate DATE, DueDate DATE,
                    Status NVARCHAR(15), Subtotal DECIMAL(12,2), TaxAmount DECIMAL(12,2),
                    TotalAmount DECIMAL(12,2), LineCount INT);
DECLARE @InvoiceId INT, @Lines INT, @Subtotal DECIMAL(12,2), @Total DECIMAL(12,2), @SumLines DECIMAL(12,2),
        @Status NVARCHAR(15), @DueOk BIT, @SecondRunError INT = NULL;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO @Out
    EXEC dbo.usp_GenerateCustomerInvoice
         @CustomerId = @CustomerId, @PeriodStart = '2000-01-01', @PeriodEnd = @Today,
         @InvoiceId = @InvoiceId OUTPUT;

    SELECT @Subtotal = i.Subtotal, @Total = i.TotalAmount, @Status = i.Status,
           @DueOk = CASE WHEN i.DueDate = DATEADD(DAY, c.PaymentTermsDays, i.IssueDate) THEN 1 ELSE 0 END
    FROM dbo.Invoices AS i
    INNER JOIN dbo.Customers AS c ON c.CustomerId = i.CustomerId
    WHERE i.InvoiceId = @InvoiceId;

    SELECT @Lines = COUNT(*), @SumLines = SUM(LineTotal)
    FROM dbo.InvoiceLines WHERE InvoiceId = @InvoiceId;

    -- Хоёр дахь удаагаа, ижил харилцагч, ижил хугацаа
    BEGIN TRY
        EXEC dbo.usp_GenerateCustomerInvoice
             @CustomerId = @CustomerId, @PeriodStart = '2000-01-01', @PeriodEnd = @Today;
    END TRY
    BEGIN CATCH
        SET @SecondRunError = ERROR_NUMBER();
    END CATCH;

    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @Detail IS NULL
BEGIN
    IF @Lines = @ExpectedLines AND @Subtotal = @ExpectedNet AND @Total = @SumLines
       AND @Status = N'Issued' AND @DueOk = 1 AND @SecondRunError = 50042
        SET @Passed = 1;
    SET @Detail = CONCAT(N'Customer ', @CustomerId, N': lines ', @Lines, N'/', @ExpectedLines,
                         N', subtotal ', @Subtotal, N'/', @ExpectedNet, N', total ', @Total, N' vs lines ', @SumLines,
                         N', status ', @Status, N', due date ok ', @DueOk, N', second run error ', @SecondRunError);
END
EXEC #RecordResult N'Procedure', N'T43 usp_GenerateCustomerInvoice bills correctly and never bills twice', @Passed, @Detail;
GO

-- T44
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_GenerateCustomerInvoice @CustomerId = 1, @PeriodStart = '2000-01-01', @PeriodEnd = '2000-01-31';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50042 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T44 usp_GenerateCustomerInvoice reports when there is nothing to bill (50042)', @Passed, @Detail;
GO

-- T45
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @InvoiceId INT, @Balance DECIMAL(12,2);
SELECT TOP (1) @InvoiceId = i.InvoiceId, @Balance = i.TotalAmount - ISNULL(p.Paid, 0)
FROM dbo.Invoices AS i
OUTER APPLY (SELECT SUM(Amount) AS Paid FROM dbo.Payments WHERE InvoiceId = i.InvoiceId) AS p
WHERE i.Status IN (N'Issued', N'PartiallyPaid', N'Overdue')
ORDER BY i.InvoiceId;
DECLARE @Amount DECIMAL(12,2) = @Balance + 100.00;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_RecordPayment @InvoiceId = @InvoiceId, @PaymentMethodId = 1,
                               @Amount = @Amount, @ReferenceNumber = N'TEST-OVERPAY';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50054 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T45 usp_RecordPayment refuses a payment larger than the balance (50054)', @Passed, @Detail;
GO

-- T46: хэсэгчилсэн төлбөр -> PartiallyPaid, үлдэгдэл зөв.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @InvoiceId INT, @Balance DECIMAL(12,2);
SELECT TOP (1) @InvoiceId = i.InvoiceId, @Balance = i.TotalAmount - ISNULL(p.Paid, 0)
FROM dbo.Invoices AS i
OUTER APPLY (SELECT SUM(Amount) AS Paid FROM dbo.Payments WHERE InvoiceId = i.InvoiceId) AS p
WHERE i.Status IN (N'Issued', N'Overdue')
  AND i.TotalAmount > 50
ORDER BY i.InvoiceId;
DECLARE @Out TABLE (PaymentId INT, InvoiceId INT, AmountPaid DECIMAL(12,2), RemainingBalance DECIMAL(12,2),
                    InvoiceStatus NVARCHAR(15), CustomerOutstandingBalance DECIMAL(12,2));
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO @Out
    EXEC dbo.usp_RecordPayment @InvoiceId = @InvoiceId, @PaymentMethodId = 1,
                               @Amount = 10.00, @ReferenceNumber = N'TEST-PART-PAYMENT';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @Detail IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM @Out WHERE InvoiceStatus = N'PartiallyPaid' AND RemainingBalance = @Balance - 10.00)
        SET @Passed = 1;
    SET @Detail = (SELECT TOP (1) CONCAT(N'Invoice ', InvoiceId, N' status ', InvoiceStatus,
                                         N', remaining ', RemainingBalance, N' (expected ', @Balance - 10.00, N')')
                   FROM @Out);
END
EXEC #RecordResult N'Procedure', N'T46 usp_RecordPayment part payment -> PartiallyPaid with correct balance', @Passed, @Detail;
GO

-- T47: paging яг нэг хуудас буцааж, нийт мөрийн бодит тоог хэлж өгнө.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @TotalRows INT;
DECLARE @Out TABLE
(
    ShipmentId BIGINT, TrackingNumber NVARCHAR(20), Status NVARCHAR(20), OriginTerminal NVARCHAR(10),
    DestinationTerminal NVARCHAR(10), ServiceCode NVARCHAR(10), CategoryName NVARCHAR(80),
    PickupDate DATE, PromisedDeliveryDate DATE, ActualDeliveryDate DATE, TotalWeightKg DECIMAL(10,2),
    TotalAmount DECIMAL(12,2), DeliveryPerformance VARCHAR(20), DaysLate INT,
    BillingStatus VARCHAR(20), InvoiceNumber NVARCHAR(20)
);
BEGIN TRY
    INSERT INTO @Out
    EXEC dbo.usp_GetCustomerShipments @CustomerId = 1, @PageNumber = 2, @PageSize = 5,
                                      @TotalRows = @TotalRows OUTPUT;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

IF @Detail IS NULL
BEGIN
    DECLARE @Expected INT = (SELECT COUNT(*) FROM dbo.fn_GetCustomerShipments(1, NULL, NULL));
    DECLARE @PageRows INT = (SELECT COUNT(*) FROM @Out);
    IF @PageRows = 5 AND @TotalRows = @Expected SET @Passed = 1;
    SET @Detail = CONCAT(N'Rows on page: ', @PageRows, N'; @TotalRows ', @TotalRows, N' vs expected ', @Expected);
END
EXEC #RecordResult N'Procedure', N'T47 usp_GetCustomerShipments pages results and returns the total row count', @Passed, @Detail;
GO

-- T42b: C1 үнэмлэх чиргүүлтэй машинд хүрэлцэхгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT TOP (1) s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = 1
  AND cc.RequiresRefrigeration = 0 AND cc.RequiresHazmat = 0
ORDER BY s.ShipmentId;
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1,                          -- ARTIC: CE ангиллын үнэмлэх шаарддаг
         @OriginTerminalId = 1, @DestinationTerminalId = 2,
         @PrimaryDriverId = 30,                   -- C1 үнэмлэх, бусдаараа тэнцэнэ
         @ScheduledDeparture = @Departure, @ShipmentIds = @Ids;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50039 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T42b usp_DispatchTrip refuses a driver whose licence class does not cover the vehicle (50039)', @Passed, @Detail;
GO

-- T42c: Таллин -> Варшав 13 цаг, 9 цагийн лимиттэй ганц жолоочид хэт урт.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT TOP (1) s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = 1          -- рейсийн эхлэл TLL-ээс
  AND cc.RequiresRefrigeration = 0 AND cc.RequiresHazmat = 0
ORDER BY s.ShipmentId;
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1, @OriginTerminalId = 1, @DestinationTerminalId = 5,
         @PrimaryDriverId = 18,                   -- 9 цагийн лимит, туслах жолоочгүй
         @ScheduledDeparture = @Departure, @ShipmentIds = @Ids;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50038 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T42c usp_DispatchTrip refuses a solo driver on a leg beyond their daily limit (50038)', @Passed, @Detail;
GO

-- T42d: usp_CompleteTrip рейсийг дуусгаж, машиныг чөлөөлж, ачааг хүргэлтэнд гаргана.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT TOP (2) s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = 1 AND cc.RequiresRefrigeration = 0
ORDER BY s.PickupDate, s.ShipmentId;

DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 6, CAST(DATEADD(DAY, 1, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(0)));
DECLARE @Arrival   DATETIME2(0) = DATEADD(MINUTE, 290, @Departure);
DECLARE @DispatchOut TABLE (TripId INT, TripNumber NVARCHAR(20), LoadWeightKg DECIMAL(12,2),
                            VehiclePayloadKg DECIMAL(10,2), PayloadUtilisationPct DECIMAL(5,2), ShipmentsLoaded INT);
DECLARE @CompleteOut TABLE (TripId INT, TripNumber NVARCHAR(20), Status NVARCHAR(20), KmDriven INT,
                            DurationHours DECIMAL(6,2), ShipmentsOutForDelivery INT, ShipmentsAwaitingTransfer INT);
DECLARE @TripId INT, @StartKm INT, @EndKm INT,
        @TripStatus NVARCHAR(20), @VehicleStatus NVARCHAR(20), @VehicleKm INT,
        @OutForDelivery INT, @Unloaded INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO @DispatchOut
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1, @OriginTerminalId = 1, @DestinationTerminalId = 2,
         @PrimaryDriverId = 17, @ScheduledDeparture = @Departure,
         @ShipmentIds = @Ids, @TripId = @TripId OUTPUT;

    SET @StartKm = (SELECT StartOdometerKm FROM dbo.Trips WHERE TripId = @TripId);
    SET @EndKm   = @StartKm + 318;

    INSERT INTO @CompleteOut
    EXEC dbo.usp_CompleteTrip
         @TripId = @TripId, @EndOdometerKm = @EndKm,
         @ActualArrival = @Arrival, @FuelLitres = 104.50;

    SET @TripStatus = (SELECT Status FROM dbo.Trips WHERE TripId = @TripId);
    SELECT @VehicleStatus = Status, @VehicleKm = OdometerKm FROM dbo.Vehicles WHERE VehicleId = 1;
    SET @OutForDelivery = (SELECT COUNT(*) FROM dbo.Shipments AS s INNER JOIN @Ids AS i ON i.Id = s.ShipmentId
                           WHERE s.Status = N'OutForDelivery');
    SET @Unloaded       = (SELECT COUNT(*) FROM dbo.TripShipments
                           WHERE TripId = @TripId AND UnloadedAt = @Arrival);

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

IF @Detail IS NULL
BEGIN
    IF @TripStatus = N'Completed' AND @VehicleStatus = N'Available' AND @VehicleKm = @EndKm
       AND @OutForDelivery = 2 AND @Unloaded = 2
       AND EXISTS (SELECT 1 FROM @CompleteOut WHERE KmDriven = 318 AND ShipmentsOutForDelivery = 2)
        SET @Passed = 1;
    SET @Detail = CONCAT(N'Trip ', @TripStatus, N'; vehicle ', @VehicleStatus, N' at ', @VehicleKm,
                         N' km (expected ', @EndKm, N'); shipments out for delivery ', @OutForDelivery,
                         N'; manifest rows unloaded ', @Unloaded);
END
EXEC #RecordResult N'Procedure', N'T42d usp_CompleteTrip completes the trip, releases the vehicle and moves freight on', @Passed, @Detail;
GO

-- T42e: эхлэлээсээ бага эцсийн одометрийг хүлээж авахгүй.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Ids dbo.IdList;
INSERT INTO @Ids (Id)
SELECT TOP (1) s.ShipmentId
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status = N'Booked' AND s.LaneId = 1 AND cc.RequiresRefrigeration = 0
ORDER BY s.ShipmentId;
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 6, CAST(DATEADD(DAY, 1, CAST(SYSUTCDATETIME() AS DATE)) AS DATETIME2(0)));
DECLARE @DispatchOut TABLE (TripId INT, TripNumber NVARCHAR(20), LoadWeightKg DECIMAL(12,2),
                            VehiclePayloadKg DECIMAL(10,2), PayloadUtilisationPct DECIMAL(5,2), ShipmentsLoaded INT);
DECLARE @TripId INT, @BadKm INT;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO @DispatchOut
    EXEC dbo.usp_DispatchTrip
         @VehicleId = 1, @OriginTerminalId = 1, @DestinationTerminalId = 2,
         @PrimaryDriverId = 17, @ScheduledDeparture = @Departure,
         @ShipmentIds = @Ids, @TripId = @TripId OUTPUT;

    SET @BadKm = (SELECT StartOdometerKm FROM dbo.Trips WHERE TripId = @TripId) - 1;
    EXEC dbo.usp_CompleteTrip @TripId = @TripId, @EndOdometerKm = @BadKm;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50072 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T42e usp_CompleteTrip refuses an end odometer below the start reading (50072)', @Passed, @Detail;
GO

-- T42f: рейсийг зөвхөн нэг удаа дуусгаж болно.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @TripId INT = (SELECT TOP (1) TripId FROM dbo.Trips WHERE Status = N'Completed' ORDER BY TripId);
DECLARE @Km INT = (SELECT EndOdometerKm FROM dbo.Trips WHERE TripId = @TripId);
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_CompleteTrip @TripId = @TripId, @EndOdometerKm = @Km;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50071 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Procedure', N'T42f usp_CompleteTrip refuses a trip that is already completed (50071)', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 8. Trigger behaviour ===';
GO

/* 8-р хэсэг - Trigger-ийн ажиллагаа */

-- T48: TR_Shipments_TrackStatus set-based: 3 мөрийн ганц UPDATE 3 audit мөр бичнэ.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @Ids TABLE (ShipmentId BIGINT PRIMARY KEY);
INSERT INTO @Ids SELECT TOP (3) ShipmentId FROM dbo.Shipments WHERE Status = N'Booked' ORDER BY ShipmentId;
DECLARE @Audited INT;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE s SET s.Status = N'PickedUp'
    FROM dbo.Shipments AS s INNER JOIN @Ids AS i ON i.ShipmentId = s.ShipmentId;

    SET @Audited = (SELECT COUNT(*) FROM dbo.ShipmentStatusHistory AS h
                    INNER JOIN @Ids AS i ON i.ShipmentId = h.ShipmentId
                    WHERE h.OldStatus = N'Booked' AND h.NewStatus = N'PickedUp');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
IF @Detail IS NULL
BEGIN
    IF @Audited = 3 SET @Passed = 1;
    SET @Detail = CONCAT(N'Audit rows written for a 3-row UPDATE: ', @Audited);
END
EXEC #RecordResult N'Trigger', N'T48 Status audit trigger handles a multi-row UPDATE', @Passed, @Detail;
GO

-- T49: төлөв өөрчлөхгүй UPDATE audit мөр бичихгүй, гэхдээ UpdatedAt шинэчлэгдэнэ.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @ShipmentId BIGINT = (SELECT TOP (1) ShipmentId FROM dbo.Shipments WHERE Status = N'Delivered' ORDER BY ShipmentId);
DECLARE @OldUpdated DATETIME2(3) = (SELECT UpdatedAt FROM dbo.Shipments WHERE ShipmentId = @ShipmentId);
DECLARE @HistBefore INT = (SELECT COUNT(*) FROM dbo.ShipmentStatusHistory WHERE ShipmentId = @ShipmentId);
DECLARE @HistAfter INT, @NewUpdated DATETIME2(3);
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Shipments SET IsInsured = 1 - IsInsured WHERE ShipmentId = @ShipmentId;
    SET @HistAfter  = (SELECT COUNT(*) FROM dbo.ShipmentStatusHistory WHERE ShipmentId = @ShipmentId);
    SET @NewUpdated = (SELECT UpdatedAt FROM dbo.Shipments WHERE ShipmentId = @ShipmentId);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
IF @Detail IS NULL
BEGIN
    IF @HistAfter = @HistBefore AND @NewUpdated > @OldUpdated SET @Passed = 1;
    SET @Detail = CONCAT(N'History rows ', @HistBefore, N'->', @HistAfter,
                         N'; UpdatedAt ', CONVERT(NVARCHAR(30), @OldUpdated, 121), N' -> ',
                         CONVERT(NVARCHAR(30), @NewUpdated, 121));
END
EXEC #RecordResult N'Trigger', N'T49 Non-status UPDATE writes no audit row but refreshes UpdatedAt', @Passed, @Detail;
GO

-- T50: хоцорсон хүргэлтийг audit-д хоцорсон гэж тэмдэглэнэ.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @ShipmentId BIGINT = (SELECT TOP (1) ShipmentId FROM dbo.Shipments WHERE Status = N'OutForDelivery' ORDER BY ShipmentId);
DECLARE @Note NVARCHAR(400);
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Shipments
    SET Status = N'Delivered', ActualDeliveryDate = DATEADD(DAY, 2, PromisedDeliveryDate)
    WHERE ShipmentId = @ShipmentId;

    SET @Note = (SELECT TOP (1) Notes FROM dbo.ShipmentStatusHistory
                 WHERE ShipmentId = @ShipmentId ORDER BY StatusHistoryId DESC);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
IF @Detail IS NULL
BEGIN
    IF @Note = N'Delivered late' SET @Passed = 1;
    SET @Detail = CONCAT(N'Audit note: "', @Note, N'"');
END
EXEC #RecordResult N'Trigger', N'T50 Status audit trigger flags a late delivery', @Passed, @Detail;
GO

-- T51: usp_RecordPayment-ийг алгассан шууд INSERT ч үлдэгдлийг барвал нэхэмжлэх Paid болно.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @InvoiceId INT, @Balance DECIMAL(12,2);
SELECT TOP (1) @InvoiceId = i.InvoiceId, @Balance = i.TotalAmount - p.Paid
FROM dbo.Invoices AS i
CROSS APPLY (SELECT SUM(Amount) AS Paid FROM dbo.Payments WHERE InvoiceId = i.InvoiceId) AS p
WHERE i.Status = N'PartiallyPaid'
ORDER BY i.InvoiceId;
DECLARE @Status NVARCHAR(15);
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Payments (InvoiceId, PaymentMethodId, PaidOn, Amount, ReferenceNumber)
    VALUES (@InvoiceId, 1, CAST(SYSUTCDATETIME() AS DATE), @Balance, N'TEST-SETTLE');
    SET @Status = (SELECT Status FROM dbo.Invoices WHERE InvoiceId = @InvoiceId);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
IF @Detail IS NULL
BEGIN
    IF @Status = N'Paid' SET @Passed = 1;
    SET @Detail = CONCAT(N'Invoice ', @InvoiceId, N' after settling ', @Balance, N': ', @Status);
END
EXEC #RecordResult N'Trigger', N'T51 Payment trigger marks an invoice Paid when the balance is cleared', @Passed, @Detail;
GO

-- T52: шууд INSERT-ээр илүү төлөхийг trigger хаана.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @InvoiceId INT, @Balance DECIMAL(12,2);
SELECT TOP (1) @InvoiceId = i.InvoiceId, @Balance = i.TotalAmount - p.Paid
FROM dbo.Invoices AS i
CROSS APPLY (SELECT SUM(Amount) AS Paid FROM dbo.Payments WHERE InvoiceId = i.InvoiceId) AS p
WHERE i.Status = N'PartiallyPaid'
ORDER BY i.InvoiceId;
DECLARE @Amount DECIMAL(12,2) = @Balance + 1.00;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Payments (InvoiceId, PaymentMethodId, PaidOn, Amount, ReferenceNumber)
    VALUES (@InvoiceId, 1, CAST(SYSUTCDATETIME() AS DATE), @Amount, N'TEST-OVERPAY-DIRECT');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50055 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Trigger', N'T52 Payment trigger blocks an overpayment inserted directly (50055)', @Passed, @Detail;
GO

-- T53: Paid нэхэмжлэхийн төлбөрийг устгахад нэхэмжлэх дахин нээгдэнэ.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @InvoiceId INT =
(
    SELECT TOP (1) i.InvoiceId
    FROM dbo.Invoices AS i
    WHERE i.Status = N'Paid'
      AND (SELECT COUNT(*) FROM dbo.Payments p WHERE p.InvoiceId = i.InvoiceId) = 1
    ORDER BY i.InvoiceId
);
DECLARE @Status NVARCHAR(15);
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM dbo.Payments WHERE InvoiceId = @InvoiceId;
    SET @Status = (SELECT Status FROM dbo.Invoices WHERE InvoiceId = @InvoiceId);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
IF @Detail IS NULL
BEGIN
    IF @Status IN (N'Issued', N'Overdue') SET @Passed = 1;
    SET @Detail = CONCAT(N'Invoice ', @InvoiceId, N' after its only payment was reversed: ', @Status);
END
EXEC #RecordResult N'Trigger', N'T53 Payment trigger reopens an invoice when its payment is deleted', @Passed, @Detail;
GO

-- T54: usp_DispatchTrip-ийг алгасаад 3.5 t машинд хэт ачихыг даацын trigger зогсооно.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000) = N'No error was raised.';
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Trips (TripNumber, VehicleId, OriginTerminalId, DestinationTerminalId,
                           ScheduledDeparture, ScheduledArrival, Status)
    VALUES (N'TRP-99999', 15, 1, 2, @Departure, DATEADD(HOUR, 5, @Departure), N'Planned');
    DECLARE @TripId INT = SCOPE_IDENTITY();

    INSERT INTO dbo.TripShipments (TripId, ShipmentId, StopSequence, LegType)
    SELECT @TripId, x.ShipmentId, ROW_NUMBER() OVER (ORDER BY x.TotalWeightKg DESC), N'LineHaul'
    FROM (SELECT TOP (2) ShipmentId, TotalWeightKg FROM dbo.Shipments ORDER BY TotalWeightKg DESC) AS x;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @Passed = CASE WHEN ERROR_NUMBER() = 50036 THEN 1 ELSE 0 END,
           @Detail = CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
EXEC #RecordResult N'Trigger', N'T54 Capacity trigger blocks an overloaded manifest (50036)', @Passed, @Detail;
GO

-- T55: харин даацад багтах ачааг trigger хүлээж авна.
DECLARE @Passed BIT = 0, @Detail NVARCHAR(2000);
DECLARE @Departure DATETIME2(0) = DATEADD(HOUR, 30, CAST(CAST(SYSUTCDATETIME() AS DATE) AS DATETIME2(0)));
DECLARE @Loaded INT;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Trips (TripNumber, VehicleId, OriginTerminalId, DestinationTerminalId,
                           ScheduledDeparture, ScheduledArrival, Status)
    VALUES (N'TRP-99999', 15, 1, 2, @Departure, DATEADD(HOUR, 5, @Departure), N'Planned');
    DECLARE @TripId INT = SCOPE_IDENTITY();

    INSERT INTO dbo.TripShipments (TripId, ShipmentId, StopSequence, LegType)
    SELECT TOP (1) @TripId, ShipmentId, 1, N'LineHaul'
    FROM dbo.Shipments WHERE TotalWeightKg BETWEEN 500 AND 3000 ORDER BY ShipmentId;

    SET @Loaded = (SELECT COUNT(*) FROM dbo.TripShipments WHERE TripId = @TripId);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Detail = CONCAT(N'Unexpected error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
IF @Detail IS NULL
BEGIN
    IF @Loaded = 1 SET @Passed = 1;
    SET @Detail = CONCAT(N'Manifest rows accepted: ', @Loaded);
END
EXEC #RecordResult N'Trigger', N'T55 Capacity trigger accepts a manifest within payload', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 9. Functions and views ===';
GO

/* 9-р хэсэг - Функц болон view */

-- T56: 1990 онд мөрдөгдөх тариф байхгүй -> quote мөр гарахгүй.
DECLARE @Rows INT = (SELECT COUNT(*) FROM dbo.fn_QuoteShipment(1, 2, 1, 1000.00, '1990-01-01'));
DECLARE @Passed BIT = CASE WHEN @Rows = 0 THEN 1 ELSE 0 END;
DECLARE @Detail NVARCHAR(200) = CONCAT(N'Quote rows returned: ', @Rows);
EXEC #RecordResult N'Function', N'T56 fn_QuoteShipment returns no row when no rate is effective', @Passed, @Detail;
GO

-- T57: 1 kg илгээмжид хамгийн бага төлбөрийг ногдуулна.
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
DECLARE @Freight DECIMAL(12,2) = (SELECT FreightCharge FROM dbo.fn_QuoteShipment(1, 2, 1, 1.00, @Today));
DECLARE @MinCharge DECIMAL(10,2) =
(
    SELECT lr.MinimumCharge
    FROM dbo.LaneRates AS lr
    WHERE lr.LaneRateId = dbo.fn_GetEffectiveLaneRateId(1, 2, @Today)
);
DECLARE @Passed BIT = CASE WHEN @Freight = @MinCharge THEN 1 ELSE 0 END;   -- STD-ийн үржүүлэгч 1.000
DECLARE @Detail NVARCHAR(200) = CONCAT(N'Freight for 1 kg: ', @Freight, N'; minimum charge: ', @MinCharge);
EXEC #RecordResult N'Function', N'T57 fn_QuoteShipment applies the minimum charge to tiny shipments', @Passed, @Detail;
GO

-- T58: үнэмлэх, ажилд байгаа эсэх, ADR шалгуур.
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
DECLARE @Expired   BIT = dbo.fn_IsDriverEligible(32, @Today, 0);   -- үнэмлэх дууссан, компаниас гарсан
DECLARE @HazmatOk  BIT = dbo.fn_IsDriverEligible(17, @Today, 1);   -- хүчинтэй, ADR зөвшөөрөлтэй
DECLARE @NoHazmat  BIT = dbo.fn_IsDriverEligible(18, @Today, 1);   -- хүчинтэй, гэхдээ ADR зөвшөөрөлгүй
DECLARE @PlainOk   BIT = dbo.fn_IsDriverEligible(18, @Today, 0);
DECLARE @Passed BIT = CASE WHEN @Expired = 0 AND @HazmatOk = 1 AND @NoHazmat = 0 AND @PlainOk = 1 THEN 1 ELSE 0 END;
DECLARE @Detail NVARCHAR(200) = CONCAT(N'expired=', @Expired, N' hazmatOk=', @HazmatOk,
                                       N' noHazmat=', @NoHazmat, N' plainOk=', @PlainOk);
EXEC #RecordResult N'Function', N'T58 fn_IsDriverEligible applies licence, employment and ADR rules', @Passed, @Detail;
GO

-- T59: view, функц хоёр үлдэгдлийг ижил тооцоолно.
DECLARE @Mismatches INT =
(
    SELECT COUNT(*)
    FROM dbo.vw_CustomerRevenueSummary AS v
    WHERE v.OutstandingBalance <> dbo.fn_CustomerOutstandingBalance(v.CustomerId)
);
DECLARE @Passed BIT = CASE WHEN @Mismatches = 0 THEN 1 ELSE 0 END;
DECLARE @Detail NVARCHAR(200) = CONCAT(@Mismatches, N' customer(s) where view and function disagree');
EXEC #RecordResult N'Function', N'T59 vw_CustomerRevenueSummary agrees with fn_CustomerOutstandingBalance', @Passed, @Detail;
GO

PRINT '';
PRINT '=== 10. Data integrity ===';
GO

/* 10-р хэсэг - Датаны бүрэн бүтэн байдал
   Хязгаарлалтаар шалгаж чадахгүй хүснэгт хоорондын дүрмүүд; зөрчилтэй мөр 0 бол тэнцэнэ. */

DECLARE @n INT;

SELECT @n = COUNT(*) FROM dbo.Shipments AS s
CROSS APPLY (SELECT CAST(SUM(LineWeightKg) AS DECIMAL(10,2)) AS w
             FROM dbo.ShipmentItems WHERE ShipmentId = s.ShipmentId) AS i
WHERE ISNULL(i.w, -1) <> s.TotalWeightKg;
EXEC #AssertZero N'T60 Shipment weight equals the sum of its item weights', @n;

SELECT @n = COUNT(*) FROM dbo.Shipments AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.ShipmentItems WHERE ShipmentId = s.ShipmentId);
EXEC #AssertZero N'T61 Every shipment has at least one item', @n;

SELECT @n = COUNT(*) FROM dbo.Shipments AS s
CROSS APPLY dbo.fn_QuoteShipment(s.LaneId, s.ServiceLevelId, s.CargoCategoryId, s.TotalWeightKg, s.PickupDate) AS q
WHERE q.FreightCharge <> s.FreightCharge
   OR q.SurchargeAmount <> s.SurchargeAmount
   OR q.TaxAmount <> s.TaxAmount;
EXEC #AssertZero N'T62 Every shipment is priced exactly as the rate card says', @n;

SELECT @n = COUNT(*) FROM dbo.Invoices AS i
CROSS APPLY (SELECT ISNULL(SUM(LineTotal), 0) AS t, ISNULL(SUM(NetAmount), 0) AS n
             FROM dbo.InvoiceLines WHERE InvoiceId = i.InvoiceId) AS l
WHERE i.TotalAmount <> l.t OR i.Subtotal <> l.n;
EXEC #AssertZero N'T63 Invoice header totals equal the sum of its lines', @n;

SELECT @n = COUNT(*) FROM dbo.Invoices AS i
CROSS APPLY (SELECT ISNULL(SUM(Amount), 0) AS Paid FROM dbo.Payments WHERE InvoiceId = i.InvoiceId) AS p
WHERE (i.Status = N'Paid'                   AND p.Paid <> i.TotalAmount)
   OR (i.Status = N'PartiallyPaid'          AND NOT (p.Paid > 0 AND p.Paid < i.TotalAmount))
   OR (i.Status IN (N'Issued', N'Overdue')  AND p.Paid <> 0);
EXEC #AssertZero N'T64 Invoice status agrees with the payments received', @n;

SELECT @n = COUNT(*) FROM dbo.InvoiceLines AS il
INNER JOIN dbo.Shipments AS s ON s.ShipmentId = il.ShipmentId
WHERE s.Status <> N'Delivered';
EXEC #AssertZero N'T65 Only delivered shipments are invoiced', @n;

SELECT @n = COUNT(*) FROM dbo.InvoiceLines AS il
INNER JOIN dbo.Invoices  AS i ON i.InvoiceId  = il.InvoiceId
INNER JOIN dbo.Shipments AS s ON s.ShipmentId = il.ShipmentId
WHERE i.CustomerId <> s.CustomerId;
EXEC #AssertZero N'T66 Invoice lines only bill the invoiced customer''s own shipments', @n;

SELECT @n = COUNT(*) FROM dbo.InvoiceLines AS il
INNER JOIN dbo.Shipments AS s ON s.ShipmentId = il.ShipmentId
WHERE il.NetAmount <> s.FreightCharge + s.SurchargeAmount;
EXEC #AssertZero N'T67 Invoice line amount equals the shipment net charge', @n;

SELECT @n = COUNT(*) FROM dbo.Trips AS t
INNER JOIN dbo.Vehicles     AS v  ON v.VehicleId     = t.VehicleId
INNER JOIN dbo.VehicleTypes AS vt ON vt.VehicleTypeId = v.VehicleTypeId
CROSS APPLY (SELECT ISNULL(SUM(s.TotalWeightKg), 0) AS w FROM dbo.TripShipments ts
             INNER JOIN dbo.Shipments s ON s.ShipmentId = ts.ShipmentId WHERE ts.TripId = t.TripId) AS m
WHERE m.w > vt.MaxPayloadKg;
EXEC #AssertZero N'T68 No trip carries more than its vehicle''s payload', @n;

SELECT @n = COUNT(*) FROM dbo.TripShipments AS ts
INNER JOIN dbo.Shipments       AS s  ON s.ShipmentId       = ts.ShipmentId
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
INNER JOIN dbo.Trips           AS t  ON t.TripId           = ts.TripId
INNER JOIN dbo.Vehicles        AS v  ON v.VehicleId        = t.VehicleId
INNER JOIN dbo.VehicleTypes    AS vt ON vt.VehicleTypeId   = v.VehicleTypeId
WHERE cc.RequiresRefrigeration = 1 AND vt.IsRefrigerated = 0;
EXEC #AssertZero N'T69 Temperature-controlled cargo only travels on refrigerated vehicles', @n;

SELECT @n = COUNT(*) FROM dbo.TripShipments AS ts
INNER JOIN dbo.Shipments AS s ON s.ShipmentId = ts.ShipmentId
INNER JOIN dbo.Lanes     AS l ON l.LaneId     = s.LaneId
INNER JOIN dbo.Trips     AS t ON t.TripId     = ts.TripId
WHERE l.OriginTerminalId <> t.OriginTerminalId
  AND l.DestinationTerminalId <> t.DestinationTerminalId;
EXEC #AssertZero N'T70 Every shipment on a trip starts or ends on that trip''s route', @n;

SELECT @n = COUNT(*) FROM dbo.Trips AS t
WHERE (SELECT COUNT(*) FROM dbo.TripDrivers WHERE TripId = t.TripId AND DriverRole = N'Primary') <> 1;
EXEC #AssertZero N'T71 Every trip has exactly one Primary driver', @n;

SELECT @n = COUNT(*) FROM dbo.TripDrivers AS td
INNER JOIN dbo.Trips   AS t ON t.TripId   = td.TripId
INNER JOIN dbo.Drivers AS d ON d.DriverId = td.DriverId
INNER JOIN dbo.Employees AS e ON e.EmployeeId = d.DriverId
WHERE d.LicenceExpiresOn < CAST(t.ScheduledDeparture AS DATE)
   OR (e.TerminationDate IS NOT NULL AND e.TerminationDate <= CAST(t.ScheduledDeparture AS DATE));
EXEC #AssertZero N'T72 No driver drove with an expired licence or after leaving', @n;

SELECT @n = COUNT(*) FROM dbo.TripDrivers AS td
INNER JOIN dbo.Trips        AS t  ON t.TripId         = td.TripId
INNER JOIN dbo.Vehicles     AS v  ON v.VehicleId      = t.VehicleId
INNER JOIN dbo.VehicleTypes AS vt ON vt.VehicleTypeId = v.VehicleTypeId
INNER JOIN dbo.Drivers      AS d  ON d.DriverId       = td.DriverId
WHERE NOT (    d.LicenceClass = 'CE'
           OR (d.LicenceClass = 'C'  AND vt.RequiredLicenceClass IN ('C', 'C1'))
           OR (d.LicenceClass = 'C1' AND vt.RequiredLicenceClass = 'C1'));
EXEC #AssertZero N'T73 Every driver''s licence class covers the vehicle they drove', @n;

-- Давхар оноолт: нэг нь нөгөөгөө дуусахаас өмнө эхэлбэл давхцана.
SELECT @n = COUNT(*) FROM dbo.Trips AS a
INNER JOIN dbo.Trips AS b ON b.VehicleId = a.VehicleId AND b.TripId > a.TripId
WHERE a.ActualDeparture < b.ActualArrival
  AND b.ActualDeparture < a.ActualArrival;
EXEC #AssertZero N'T73b No vehicle is booked on two overlapping trips', @n;

SELECT @n = COUNT(*) FROM dbo.TripDrivers AS da
INNER JOIN dbo.Trips       AS a  ON a.TripId   = da.TripId
INNER JOIN dbo.TripDrivers AS db ON db.DriverId = da.DriverId AND db.TripId > da.TripId
INNER JOIN dbo.Trips       AS b  ON b.TripId   = db.TripId
WHERE a.ActualDeparture < b.ActualArrival
  AND b.ActualDeparture < a.ActualArrival;
EXEC #AssertZero N'T73c No driver is rostered on two overlapping trips', @n;

-- Одометр: заалт зөвхөн өсөх ёстой.
SELECT @n = COUNT(*) FROM
(
    SELECT StartOdometerKm,
           LAG(EndOdometerKm) OVER (PARTITION BY VehicleId ORDER BY ActualDeparture, TripId) AS PreviousEnd
    FROM dbo.Trips
) AS x
WHERE x.StartOdometerKm < x.PreviousEnd;
EXEC #AssertZero N'T73d A vehicle''s odometer never goes backwards from one trip to the next', @n;

SELECT @n = (SELECT COUNT(*) FROM dbo.Trips AS t
             INNER JOIN dbo.Vehicles AS v ON v.VehicleId = t.VehicleId
             WHERE t.EndOdometerKm > v.OdometerKm)
          + (SELECT COUNT(*) FROM dbo.MaintenanceRecords AS mr
             INNER JOIN dbo.Vehicles AS v ON v.VehicleId = mr.VehicleId
             WHERE mr.OdometerKm > v.OdometerKm);
EXEC #AssertZero N'T73e No trip or workshop reading is above the vehicle''s current odometer', @n;

SELECT @n = COUNT(*) FROM dbo.MaintenanceRecords AS mr
OUTER APPLY (SELECT TOP (1) t.EndOdometerKm
             FROM dbo.Trips AS t
             WHERE t.VehicleId = mr.VehicleId
               AND CAST(t.ActualArrival AS DATE) <= mr.PerformedOn
             ORDER BY t.ActualArrival DESC) AS prev
OUTER APPLY (SELECT TOP (1) t.StartOdometerKm
             FROM dbo.Trips AS t
             WHERE t.VehicleId = mr.VehicleId
               AND CAST(t.ActualDeparture AS DATE) > mr.PerformedOn
             ORDER BY t.ActualDeparture) AS nxt
WHERE mr.OdometerKm < ISNULL(prev.EndOdometerKm, 0)
   OR mr.OdometerKm > ISNULL(nxt.StartOdometerKm, 2147483647);
EXEC #AssertZero N'T73f Workshop odometer readings fit between the surrounding trips', @n;

SELECT @n = COUNT(*) FROM dbo.MaintenanceRecords AS mr
INNER JOIN dbo.Trips AS t ON t.VehicleId = mr.VehicleId
WHERE mr.PerformedOn BETWEEN CAST(t.ActualDeparture AS DATE) AND CAST(t.ActualArrival AS DATE);
EXEC #AssertZero N'T73g No vehicle is in the workshop on a day it is out on a trip', @n;

-- Жолоочийн шаардлага
SELECT @n = COUNT(*) FROM dbo.TripDrivers AS td
INNER JOIN dbo.Drivers AS d ON d.DriverId = td.DriverId
WHERE d.HasHazmatEndorsement = 0
  AND EXISTS (SELECT 1
              FROM dbo.TripShipments         AS ts
              INNER JOIN dbo.Shipments       AS s  ON s.ShipmentId       = ts.ShipmentId
              INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
              WHERE ts.TripId = td.TripId
                AND cc.RequiresHazmat = 1);
EXEC #AssertZero N'T73h Every driver on a dangerous-goods trip holds an ADR endorsement', @n;

SELECT @n = COUNT(*) FROM dbo.TripDrivers AS td
INNER JOIN dbo.Trips   AS t ON t.TripId   = td.TripId
INNER JOIN dbo.Drivers AS d ON d.DriverId = td.DriverId
INNER JOIN dbo.Lanes   AS l ON l.OriginTerminalId      = t.OriginTerminalId
                           AND l.DestinationTerminalId = t.DestinationTerminalId
CROSS APPLY (SELECT COUNT(*) AS CrewSize FROM dbo.TripDrivers WHERE TripId = t.TripId) AS c
WHERE l.EstimatedDrivingHours / c.CrewSize > d.MaxDailyDrivingHours;
EXEC #AssertZero N'T73i No driver exceeds their daily driving limit on any trip', @n;

-- Цаг хугацааны дараалал
SELECT @n = COUNT(*) FROM dbo.Shipments AS s
INNER JOIN dbo.TripShipments AS ts ON ts.ShipmentId = s.ShipmentId
INNER JOIN dbo.Trips         AS t  ON t.TripId      = ts.TripId
WHERE s.ActualDeliveryDate < CAST(t.ActualArrival AS DATE);
EXEC #AssertZero N'T73j No shipment is delivered before the truck carrying it arrived', @n;

SELECT @n = COUNT(*) FROM dbo.Shipments AS s
INNER JOIN dbo.Lanes     AS l  ON l.LaneId     = s.LaneId
INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
INNER JOIN dbo.Addresses AS ta ON ta.AddressId  = ot.AddressId
INNER JOIN dbo.Cities    AS tc ON tc.CityId     = ta.CityId
INNER JOIN dbo.Addresses AS sa ON sa.AddressId  = s.OriginAddressId
INNER JOIN dbo.Cities    AS sc ON sc.CityId     = sa.CityId
WHERE sc.CountryId <> tc.CountryId;
EXEC #AssertZero N'T74 Shipments are collected in their origin terminal''s country', @n;

SELECT @n = COUNT(*) FROM dbo.Shipments AS s
WHERE NOT EXISTS (SELECT 1 FROM dbo.ShipmentStatusHistory
                  WHERE ShipmentId = s.ShipmentId AND OldStatus IS NULL);
EXEC #AssertZero N'T75 Every shipment has an opening audit row', @n;

SELECT @n = COUNT(*) FROM dbo.Shipments AS s
CROSS APPLY (SELECT TOP (1) NewStatus FROM dbo.ShipmentStatusHistory
             WHERE ShipmentId = s.ShipmentId ORDER BY StatusHistoryId DESC) AS h
WHERE h.NewStatus <> s.Status;
EXEC #AssertZero N'T76 The latest audit row matches each shipment''s current status', @n;

SELECT @n = COUNT(*) FROM dbo.Employees AS e
INNER JOIN dbo.Employees AS m ON m.EmployeeId = e.ManagerId
WHERE m.TerminationDate IS NOT NULL AND e.TerminationDate IS NULL;
EXEC #AssertZero N'T77 No current employee reports to someone who has left', @n;
GO

-- T78 / T79: sequence-үүд ашиглагдсан дугаараас түрүүлж байх ёстой, эс тэгвэл жишээ дататай давхцана.
-- NEXT VALUE FOR нэг утга зарцуулдаг ч хор хөнөөлгүй.
DECLARE @n INT;

DECLARE @NextTracking INT = NEXT VALUE FOR dbo.seq_TrackingNumber;
SELECT @n = COUNT(*) FROM dbo.Shipments
WHERE CAST(SUBSTRING(TrackingNumber, 3, 8) AS INT) >= @NextTracking;
EXEC #AssertZero N'T78 seq_TrackingNumber is ahead of every tracking number in use', @n;

DECLARE @NextTrip INT = NEXT VALUE FOR dbo.seq_TripNumber;
SELECT @n = COUNT(*) FROM dbo.Trips
WHERE CAST(SUBSTRING(TripNumber, 5, 5) AS INT) >= @NextTrip;
EXEC #AssertZero N'T79 seq_TripNumber is ahead of every trip number in use', @n;
GO

PRINT '';
PRINT '=== 11. Suite hygiene ===';
GO

/* 11-р хэсэг - Датаг хэвээр үлдээсэн эсэх */

-- T80: тестүүд датаг яг байсан хэвээр нь үлдээх ёстой.
DECLARE @Current TABLE (TableName VARCHAR(40), RowCnt BIGINT, Chk INT);
INSERT INTO @Current
SELECT 'Shipments', COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(ShipmentId, Status, ActualDeliveryDate, IsInsured)) FROM dbo.Shipments
UNION ALL SELECT 'ShipmentItems',         COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(ShipmentItemId))       FROM dbo.ShipmentItems
UNION ALL SELECT 'ShipmentStatusHistory', COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(StatusHistoryId, Notes)) FROM dbo.ShipmentStatusHistory
UNION ALL SELECT 'Trips',                 COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(TripId, Status, ActualArrival)) FROM dbo.Trips
UNION ALL SELECT 'TripDrivers',           COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(TripId, DriverId))     FROM dbo.TripDrivers
UNION ALL SELECT 'TripShipments',         COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(TripId, ShipmentId))   FROM dbo.TripShipments
UNION ALL SELECT 'Invoices',              COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(InvoiceId, Status))    FROM dbo.Invoices
UNION ALL SELECT 'InvoiceLines',          COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(InvoiceLineId))        FROM dbo.InvoiceLines
UNION ALL SELECT 'Payments',              COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(PaymentId, Amount))    FROM dbo.Payments
UNION ALL SELECT 'Customers',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(CustomerId, CreditLimit, TaxNumber)) FROM dbo.Customers
UNION ALL SELECT 'CustomerContacts',      COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(ContactId, IsPrimary)) FROM dbo.CustomerContacts
UNION ALL SELECT 'Countries',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(CountryId))            FROM dbo.Countries
UNION ALL SELECT 'Employees',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(EmployeeId, ManagerId)) FROM dbo.Employees
UNION ALL SELECT 'Drivers',               COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(DriverId, LicenceExpiresOn)) FROM dbo.Drivers
UNION ALL SELECT 'Vehicles',              COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(VehicleId, Status, VIN)) FROM dbo.Vehicles
UNION ALL SELECT 'Lanes',                 COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(LaneId))               FROM dbo.Lanes
UNION ALL SELECT 'LaneRates',             COUNT_BIG(*), CHECKSUM_AGG(CHECKSUM(LaneRateId))           FROM dbo.LaneRates;

DECLARE @Changed NVARCHAR(2000) =
(
    SELECT STRING_AGG(CONCAT(b.TableName, N' (rows ', b.RowCnt, N'->', c.RowCnt, N')'), N', ')
    FROM #Baseline AS b
    INNER JOIN @Current AS c ON c.TableName = b.TableName
    WHERE b.RowCnt <> c.RowCnt OR ISNULL(b.Chk, 0) <> ISNULL(c.Chk, 0)
);
DECLARE @Passed BIT = CASE WHEN @Changed IS NULL THEN 1 ELSE 0 END;
DECLARE @Detail NVARCHAR(2000) = ISNULL(N'Changed: ' + @Changed, N'All 17 monitored tables unchanged.');
EXEC #RecordResult N'Hygiene', N'T80 The test suite left all data exactly as it found it', @Passed, @Detail;
GO

/* Дүгнэлт */

PRINT '';
PRINT '=== SUMMARY ===';

SELECT
    Category,
    COUNT(*)                                     AS Tests,
    SUM(CAST(Passed AS INT))                     AS Passed,
    COUNT(*) - SUM(CAST(Passed AS INT))          AS Failed
FROM #TestResults
GROUP BY Category
ORDER BY MIN(TestNo);

SELECT TestNo, Category, TestName, Detail
FROM #TestResults
WHERE Passed = 0
ORDER BY TestNo;

DECLARE @Total  INT = (SELECT COUNT(*) FROM #TestResults);
DECLARE @Failed INT = (SELECT COUNT(*) FROM #TestResults WHERE Passed = 0);

PRINT CONCAT(N'Tests run: ', @Total, N'   Passed: ', @Total - @Failed, N'   Failed: ', @Failed);

IF @Failed > 0
BEGIN
    DECLARE @Msg NVARCHAR(200) = CONCAT(@Failed, N' of ', @Total, N' database tests failed.');
    THROW 50099, @Msg, 1;
END
ELSE
    PRINT N'ALL TESTS PASSED';
GO
