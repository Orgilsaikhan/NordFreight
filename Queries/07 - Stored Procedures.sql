/*
  NordFreight Logistics -- 07 - Stored процедурууд
  8 процедур: ачаа захиалах, төлөв солих, dispatch, рейс дуусгах, нэхэмжлэх, төлбөр, портал хайлт, сарын тайлан.
  Бичдэг процедур бүр: NOCOUNT + XACT_ABORT ON, TRY дотор транзакц, CATCH-д ROLLBACK + THROW.
  XACT_ABORT-гүй бол алдаатай STATEMENT л зогсож, COMMIT хагас ажлыг хадгалчихна ("11 - Tests.sql", T28).
  Алдааны дугаар: 5001x үүсгэх, 5002x төлөв, 5003x dispatch, 5004x нэхэмжлэх, 5005x төлбөр, 5006x тайлан, 5007x рейс дуусгах.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
  Table-valued parameter төрлүүд: ачааг бараатай нь нэг дуудлагаар үүсгэхэд хэрэглэнэ.
  CREATE TYPE-д OR ALTER байхгүй тул шалгаж үүсгэнэ; өөрчлөх бол эхлээд процедуруудаа drop хий.
*/

IF TYPE_ID(N'dbo.ShipmentItemList') IS NULL
    CREATE TYPE dbo.ShipmentItemList AS TABLE
    (
        LineNumber    SMALLINT      NOT NULL PRIMARY KEY,
        Description   NVARCHAR(200) NOT NULL,
        Quantity      INT           NOT NULL,
        UnitWeightKg  DECIMAL(9,3)  NOT NULL,
        UnitVolumeM3  DECIMAL(9,4)  NOT NULL,
        PackagingType NVARCHAR(20)  NOT NULL
    );
GO

IF TYPE_ID(N'dbo.IdList') IS NULL
    CREATE TYPE dbo.IdList AS TABLE
    (
        Id BIGINT NOT NULL PRIMARY KEY
    );
GO

/*
  usp_CreateShipment - ачааг шалгаж, fn_QuoteShipment-ээр үнэлж, зээлийг шалгаад
  бараатай нь нэг транзакцаар бичнэ. Харилцагчийн мөрийг UPDLOCK-той уншдаг:
  зэрэг 2 захиалга нэг зээлийн үлдэгдлийг давхар ашиглаж чадахгүй.
*/
CREATE OR ALTER PROCEDURE dbo.usp_CreateShipment
    @CustomerId           INT,
    @LaneId               INT,
    @ServiceLevelId       INT,
    @CargoCategoryId      INT,
    @OriginAddressId      INT,
    @DestinationAddressId INT,
    @Items                dbo.ShipmentItemList READONLY,
    @PickupDate           DATE           = NULL,   -- өгөхгүй бол өнөөдөр
    @DeclaredValue        DECIMAL(12,2)  = 0,
    @IsInsured            BIT            = 0,
    @ShipmentId           BIGINT         = NULL OUTPUT,
    @TrackingNumber       NVARCHAR(20)   = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @PickupDate = ISNULL(@PickupDate, CAST(SYSUTCDATETIME() AS DATE));

    DECLARE @Msg NVARCHAR(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Шалгах
        IF NOT EXISTS (SELECT 1 FROM @Items)
            THROW 50010, 'A shipment must contain at least one item.', 1;

        IF EXISTS (SELECT 1 FROM @Items
                   WHERE Quantity <= 0 OR UnitWeightKg <= 0 OR UnitVolumeM3 <= 0)
            THROW 50010, 'Every item needs a positive quantity, weight and volume.', 1;

        DECLARE @CustomerActive BIT, @CreditLimit DECIMAL(12,2);

        -- UPDLOCK: зэрэг ирсэн захиалгуудыг ээлжлүүлнэ
        SELECT @CustomerActive = c.IsActive,
               @CreditLimit    = c.CreditLimit
        FROM dbo.Customers AS c WITH (UPDLOCK, ROWLOCK)
        WHERE c.CustomerId = @CustomerId;

        IF @CustomerActive IS NULL
        BEGIN
            SET @Msg = FORMATMESSAGE('Customer %d does not exist.', @CustomerId);
            THROW 50011, @Msg, 1;
        END

        IF @CustomerActive = 0
        BEGIN
            SET @Msg = FORMATMESSAGE('Customer %d is inactive and cannot book freight.', @CustomerId);
            THROW 50011, @Msg, 1;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Lanes WHERE LaneId = @LaneId AND IsActive = 1)
        BEGIN
            SET @Msg = FORMATMESSAGE('Lane %d does not exist or is not active.', @LaneId);
            THROW 50012, @Msg, 1;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.ServiceLevels
                       WHERE ServiceLevelId = @ServiceLevelId AND IsActive = 1)
            THROW 50013, 'The requested service level does not exist or is not active.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.CargoCategories WHERE CargoCategoryId = @CargoCategoryId)
            THROW 50014, 'The requested cargo category does not exist.', 1;

        IF @OriginAddressId = @DestinationAddressId
            THROW 50015, 'Origin and destination addresses must be different.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Addresses WHERE AddressId = @OriginAddressId)
         OR NOT EXISTS (SELECT 1 FROM dbo.Addresses WHERE AddressId = @DestinationAddressId)
            THROW 50015, 'Origin or destination address does not exist.', 1;

        IF @PickupDate < CAST(SYSUTCDATETIME() AS DATE)
            THROW 50016, 'Pickup date cannot be in the past.', 1;

        -- 2. Нийт жин, эзэлхүүнийг бараанаас бодох
        DECLARE @TotalWeightKg DECIMAL(10,2),
                @TotalVolumeM3 DECIMAL(10,3);

        SELECT @TotalWeightKg = CAST(SUM(Quantity * UnitWeightKg) AS DECIMAL(10,2)),
               @TotalVolumeM3 = CAST(SUM(Quantity * UnitVolumeM3) AS DECIMAL(10,3))
        FROM @Items;

        -- Ангилал дээр зарласан үнийн хязгаар байвал шалгана
        DECLARE @MaxDeclaredValue DECIMAL(12,2) =
        (
            SELECT MaxDeclaredValue FROM dbo.CargoCategories
            WHERE CargoCategoryId = @CargoCategoryId
        );

        IF @MaxDeclaredValue IS NOT NULL AND @DeclaredValue > @MaxDeclaredValue
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Declared value %s exceeds the %s limit for this cargo category.',
                CAST(CAST(@DeclaredValue AS DECIMAL(12,2)) AS NVARCHAR(30)),
                CAST(CAST(@MaxDeclaredValue AS DECIMAL(12,2)) AS NVARCHAR(30)));
            THROW 50017, @Msg, 1;
        END

        -- 3. Үнэ бодох
        DECLARE @FreightCharge   DECIMAL(12,2),
                @SurchargeAmount DECIMAL(12,2),
                @TaxAmount       DECIMAL(12,2),
                @QuotedTotal     DECIMAL(12,2);

        SELECT @FreightCharge   = q.FreightCharge,
               @SurchargeAmount = q.SurchargeAmount,
               @TaxAmount       = q.TaxAmount,
               @QuotedTotal     = q.TotalAmount
        FROM dbo.fn_QuoteShipment(@LaneId, @ServiceLevelId, @CargoCategoryId,
                                  @TotalWeightKg, @PickupDate) AS q;

        IF @FreightCharge IS NULL
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'No rate is on file for lane %d / service level %d effective on that date.',
                @LaneId, @ServiceLevelId);
            THROW 50018, @Msg, 1;
        END

        -- 4. Зээлийн хяналт
        DECLARE @AvailableCredit DECIMAL(12,2) = dbo.fn_CustomerAvailableCredit(@CustomerId);

        IF @CreditLimit > 0 AND @QuotedTotal > @AvailableCredit
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Booking of %s exceeds available credit of %s for customer %d.',
                CAST(@QuotedTotal     AS NVARCHAR(30)),
                CAST(@AvailableCredit AS NVARCHAR(30)),
                @CustomerId);
            THROW 50019, @Msg, 1;
        END

        -- 5. Ачаа, бараануудыг бичих
        DECLARE @Seq INT = NEXT VALUE FOR dbo.seq_TrackingNumber;
        SET @TrackingNumber = N'NF' + RIGHT(N'00000000' + CAST(@Seq AS NVARCHAR(10)), 8);

        DECLARE @TransitDays INT =
        (
            SELECT MaxTransitDays FROM dbo.ServiceLevels WHERE ServiceLevelId = @ServiceLevelId
        );

        INSERT INTO dbo.Shipments
        (
            TrackingNumber, CustomerId, LaneId, ServiceLevelId, CargoCategoryId,
            OriginAddressId, DestinationAddressId, PickupDate, PromisedDeliveryDate,
            Status, TotalWeightKg, TotalVolumeM3, DeclaredValue,
            FreightCharge, SurchargeAmount, TaxAmount, IsInsured
        )
        VALUES
        (
            @TrackingNumber, @CustomerId, @LaneId, @ServiceLevelId, @CargoCategoryId,
            @OriginAddressId, @DestinationAddressId, @PickupDate,
            DATEADD(DAY, @TransitDays, @PickupDate),
            N'Booked', @TotalWeightKg, @TotalVolumeM3, @DeclaredValue,
            @FreightCharge, @SurchargeAmount, @TaxAmount, @IsInsured
        );

        SET @ShipmentId = SCOPE_IDENTITY();

        INSERT INTO dbo.ShipmentItems
            (ShipmentId, LineNumber, Description, Quantity,
             UnitWeightKg, UnitVolumeM3, PackagingType)
        SELECT @ShipmentId, i.LineNumber, i.Description, i.Quantity,
               i.UnitWeightKg, i.UnitVolumeM3, i.PackagingType
        FROM @Items AS i;

        COMMIT TRANSACTION;

        -- 'Booked' түүхийн мөрийг TR_Shipments_TrackStatus бичнэ
        SELECT @ShipmentId AS ShipmentId, @TrackingNumber AS TrackingNumber,
               @TotalWeightKg AS TotalWeightKg, @FreightCharge AS FreightCharge,
               @SurchargeAmount AS SurchargeAmount, @TaxAmount AS TaxAmount,
               @QuotedTotal AS TotalAmount;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*
  usp_UpdateShipmentStatus - ачааны төлөвийг солино, дүрмүүд нь VALUES хүснэгтэд (IF-ийн гинж биш):
  Booked -> PickedUp -> InTransit -> OutForDelivery -> Delivered, замаас Exception/Cancelled руу гарч болно.
  Delivered, Cancelled эцсийн. Түүхийн мөрийг trigger бичдэг тул шууд UPDATE ч audit-д орно.
*/
CREATE OR ALTER PROCEDURE dbo.usp_UpdateShipmentStatus
    @ShipmentId         BIGINT,
    @NewStatus          NVARCHAR(20),
    @TerminalId         INT           = NULL,
    @ActualDeliveryDate DATE          = NULL,
    @Notes              NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Msg NVARCHAR(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus NVARCHAR(20), @PickupDate DATE;

        SELECT @CurrentStatus = s.Status,
               @PickupDate    = s.PickupDate
        FROM dbo.Shipments AS s WITH (UPDLOCK, ROWLOCK)
        WHERE s.ShipmentId = @ShipmentId;

        IF @CurrentStatus IS NULL
        BEGIN
            SET @Msg = FORMATMESSAGE('Shipment %I64d does not exist.', @ShipmentId);
            THROW 50020, @Msg, 1;
        END

        IF @CurrentStatus = @NewStatus
        BEGIN
            SET @Msg = FORMATMESSAGE('Shipment is already in status %s.', @NewStatus);
            THROW 50021, @Msg, 1;
        END

        -- Зөвшөөрөгдсөн шилжилтүүд (state machine)
        DECLARE @Allowed TABLE (FromStatus NVARCHAR(20), ToStatus NVARCHAR(20));
        INSERT INTO @Allowed (FromStatus, ToStatus) VALUES
            (N'Booked',         N'PickedUp'),
            (N'Booked',         N'Cancelled'),
            (N'Booked',         N'Exception'),
            (N'PickedUp',       N'InTransit'),
            (N'PickedUp',       N'Exception'),
            (N'PickedUp',       N'Cancelled'),
            (N'InTransit',      N'OutForDelivery'),
            (N'InTransit',      N'Exception'),
            (N'InTransit',      N'Cancelled'),
            (N'OutForDelivery', N'Delivered'),
            (N'OutForDelivery', N'Exception'),
            (N'Exception',      N'InTransit'),
            (N'Exception',      N'OutForDelivery'),
            (N'Exception',      N'Delivered'),
            (N'Exception',      N'Cancelled');

        IF NOT EXISTS (SELECT 1 FROM @Allowed
                       WHERE FromStatus = @CurrentStatus AND ToStatus = @NewStatus)
        BEGIN
            SET @Msg = FORMATMESSAGE('Illegal status transition: %s -> %s.',
                                     @CurrentStatus, @NewStatus);
            THROW 50022, @Msg, 1;
        END

        -- Хүргэсэн огноо өгөөгүй бол өнөөдөр
        IF @NewStatus = N'Delivered'
        BEGIN
            SET @ActualDeliveryDate = ISNULL(@ActualDeliveryDate, CAST(SYSUTCDATETIME() AS DATE));

            IF @ActualDeliveryDate < @PickupDate
                THROW 50023, 'Delivery date cannot be earlier than the pickup date.', 1;
        END

        -- Нэхэмжлэхэд орсон ачааг цуцлахгүй
        IF @NewStatus = N'Cancelled'
           AND EXISTS (SELECT 1 FROM dbo.InvoiceLines WHERE ShipmentId = @ShipmentId)
            THROW 50024, 'Cannot cancel a shipment that has already been invoiced.', 1;

        UPDATE dbo.Shipments
        SET Status             = @NewStatus,
            ActualDeliveryDate = CASE WHEN @NewStatus = N'Delivered'
                                      THEN @ActualDeliveryDate
                                      ELSE ActualDeliveryDate END,
            UpdatedAt          = SYSUTCDATETIME()
        WHERE ShipmentId = @ShipmentId;

        -- Trigger-ийн бичсэн audit мөрөнд терминал, тэмдэглэлийг нэмнэ
        IF @TerminalId IS NOT NULL OR @Notes IS NOT NULL
        BEGIN
            UPDATE h
            SET TerminalId = ISNULL(@TerminalId, h.TerminalId),
                Notes      = ISNULL(@Notes, h.Notes)
            FROM dbo.ShipmentStatusHistory AS h
            WHERE h.StatusHistoryId =
            (
                SELECT MAX(h2.StatusHistoryId)
                FROM dbo.ShipmentStatusHistory AS h2
                WHERE h2.ShipmentId = @ShipmentId
            );
        END

        COMMIT TRANSACTION;

        SELECT @ShipmentId AS ShipmentId,
               @CurrentStatus AS PreviousStatus,
               @NewStatus AS CurrentStatus;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*
  usp_DispatchTrip - рейс, экипаж, ачааны жагсаалтыг бичиж, машин, ачааны төлөвийг солино.
  Бүгд нэг транзакц, учир нь хагас гарсан рейс (OnTrip мөртлөө жагсаалтгүй) огт рейсгүйгээс дор.
  Шалгалт: машин Available, ачаа идэвхтэй/өөр рейсгүй/маршрутдаа, даац, хөргүүр, жолоочийн эрх, ADR, цаг.
  Ачааг UPDLOCK-той уншдаг: 2 dispatcher нэг ачааг зэрэг 2 машинд ачиж чадахгүй.
*/
CREATE OR ALTER PROCEDURE dbo.usp_DispatchTrip
    @VehicleId             INT,
    @OriginTerminalId      INT,
    @DestinationTerminalId INT,
    @PrimaryDriverId       INT,
    @ScheduledDeparture    DATETIME2(0),
    @ShipmentIds           dbo.IdList READONLY,
    @CoDriverId            INT    = NULL,
    @TripId                INT    = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Msg NVARCHAR(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Машин
        DECLARE @VehicleStatus   NVARCHAR(20),
                @MaxPayloadKg    DECIMAL(10,2),
                @MaxVolumeM3     DECIMAL(10,2),
                @IsRefrigerated  BIT,
                @RequiredClass   VARCHAR(2),
                @VehicleOdometer INT;

        SELECT @VehicleStatus   = v.Status,
               @MaxPayloadKg    = vt.MaxPayloadKg,
               @MaxVolumeM3     = vt.MaxVolumeM3,
               @IsRefrigerated  = vt.IsRefrigerated,
               @RequiredClass   = vt.RequiredLicenceClass,
               @VehicleOdometer = v.OdometerKm
        FROM dbo.Vehicles AS v WITH (UPDLOCK, ROWLOCK)
        INNER JOIN dbo.VehicleTypes AS vt ON vt.VehicleTypeId = v.VehicleTypeId
        WHERE v.VehicleId = @VehicleId;

        IF @VehicleStatus IS NULL
        BEGIN
            SET @Msg = FORMATMESSAGE('Vehicle %d does not exist.', @VehicleId);
            THROW 50030, @Msg, 1;
        END

        IF @VehicleStatus <> N'Available'
        BEGIN
            SET @Msg = FORMATMESSAGE('Vehicle %d is not available (status: %s).',
                                     @VehicleId, @VehicleStatus);
            THROW 50030, @Msg, 1;
        END

        IF @OriginTerminalId = @DestinationTerminalId
            THROW 50030, 'A trip must start and end at different terminals.', 1;

        -- 2. Ачааны жагсаалт (экипажаас өмнө шалгана)
        IF NOT EXISTS (SELECT 1 FROM @ShipmentIds)
            THROW 50033, 'A trip must carry at least one shipment.', 1;

        DECLARE @RequestedCount INT = (SELECT COUNT(*) FROM @ShipmentIds);

        -- Эхлээд lock: дараагийн шалгалтууд өөр dispatch-ийн commit-ийг харна
        DECLARE @MatchedCount   INT =
        (
            SELECT COUNT(*)
            FROM dbo.Shipments AS s WITH (UPDLOCK, ROWLOCK)
            INNER JOIN @ShipmentIds AS x ON x.Id = s.ShipmentId
        );

        IF @MatchedCount <> @RequestedCount
            THROW 50033, 'One or more of the supplied shipment ids does not exist.', 1;

        IF EXISTS (SELECT 1
                   FROM dbo.Shipments AS s
                   INNER JOIN @ShipmentIds AS x ON x.Id = s.ShipmentId
                   WHERE s.Status NOT IN (N'Booked', N'PickedUp', N'InTransit', N'Exception'))
            THROW 50033, 'Only shipments that are still in progress can be loaded onto a trip.', 1;

        -- Дуусаагүй рейсэнд ачигдсан эсэх
        IF EXISTS (SELECT 1
                   FROM dbo.TripShipments AS ts
                   INNER JOIN @ShipmentIds AS x ON x.Id = ts.ShipmentId
                   INNER JOIN dbo.Trips    AS t ON t.TripId = ts.TripId
                   WHERE t.Status IN (N'Planned', N'Dispatched', N'InProgress'))
            THROW 50033, 'One or more shipments are already assigned to an active trip.', 1;

        -- Ачаа энэ маршрутаар эхлэх/дуусах ёстой: hub дамжлага болно, буруу зүг болохгүй
        IF EXISTS (SELECT 1
                   FROM dbo.Shipments AS s
                   INNER JOIN @ShipmentIds AS x ON x.Id = s.ShipmentId
                   INNER JOIN dbo.Lanes    AS l ON l.LaneId = s.LaneId
                   WHERE l.OriginTerminalId      <> @OriginTerminalId
                     AND l.DestinationTerminalId <> @DestinationTerminalId)
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'One or more shipments neither start at terminal %d nor finish at terminal %d.',
                @OriginTerminalId, @DestinationTerminalId);
            THROW 50037, @Msg, 1;
        END

        DECLARE @LoadWeightKg DECIMAL(12,2),
                @LoadVolumeM3 DECIMAL(12,3),
                @NeedsReefer  BIT,
                @NeedsHazmat  BIT;

        SELECT @LoadWeightKg = SUM(s.TotalWeightKg),
               @LoadVolumeM3 = SUM(s.TotalVolumeM3),
               @NeedsReefer  = MAX(CAST(cc.RequiresRefrigeration AS TINYINT)),
               @NeedsHazmat  = MAX(CAST(cc.RequiresHazmat        AS TINYINT))
        FROM dbo.Shipments AS s
        INNER JOIN @ShipmentIds        AS x  ON x.Id = s.ShipmentId
        INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId;

        IF @LoadWeightKg > @MaxPayloadKg
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Load of %s kg exceeds the %s kg payload of vehicle %d.',
                CAST(@LoadWeightKg AS NVARCHAR(30)),
                CAST(@MaxPayloadKg AS NVARCHAR(30)), @VehicleId);
            THROW 50034, @Msg, 1;
        END

        IF @LoadVolumeM3 > @MaxVolumeM3
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Load of %s m3 exceeds the %s m3 capacity of vehicle %d.',
                CAST(@LoadVolumeM3 AS NVARCHAR(30)),
                CAST(@MaxVolumeM3  AS NVARCHAR(30)), @VehicleId);
            THROW 50034, @Msg, 1;
        END

        IF @NeedsReefer = 1 AND @IsRefrigerated = 0
            THROW 50035, 'This load contains temperature-controlled cargo but the vehicle is not refrigerated.', 1;

        -- 3. Экипаж
        DECLARE @DepartureDate DATE = CAST(@ScheduledDeparture AS DATE);

        IF dbo.fn_IsDriverEligible(@PrimaryDriverId, @DepartureDate, @NeedsHazmat) = 0
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Driver %d is not eligible for this trip (licence, medical, employment or hazmat endorsement).',
                @PrimaryDriverId);
            THROW 50031, @Msg, 1;
        END

        IF @CoDriverId IS NOT NULL
        BEGIN
            IF @CoDriverId = @PrimaryDriverId
                THROW 50032, 'The co-driver must be a different person from the primary driver.', 1;

            IF dbo.fn_IsDriverEligible(@CoDriverId, @DepartureDate, @NeedsHazmat) = 0
            BEGIN
                SET @Msg = FORMATMESSAGE('Co-driver %d is not eligible for this trip.', @CoDriverId);
                THROW 50032, @Msg, 1;
            END
        END

        -- Үнэмлэх: CE нь C, C1-ийг, C нь C1-ийг хамарна; NULL @CoDriverId IN дотор таарахгүй
        IF EXISTS
        (
            SELECT 1
            FROM dbo.Drivers AS d
            WHERE d.DriverId IN (@PrimaryDriverId, @CoDriverId)
              AND NOT (    d.LicenceClass = 'CE'
                       OR (d.LicenceClass = 'C'  AND @RequiredClass IN ('C', 'C1'))
                       OR (d.LicenceClass = 'C1' AND @RequiredClass = 'C1'))
        )
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'A rostered driver''s licence does not cover this vehicle (class %s required).',
                @RequiredClass);
            THROW 50039, @Msg, 1;
        END

        -- Жолоодох цагийг экипажид хуваана; урт замд туслах жолооч хэрэгтэй
        DECLARE @DrivingHours DECIMAL(5,2) =
        (
            SELECT TOP (1) l.EstimatedDrivingHours
            FROM dbo.Lanes AS l
            WHERE l.OriginTerminalId      = @OriginTerminalId
              AND l.DestinationTerminalId = @DestinationTerminalId
        );
        SET @DrivingHours = ISNULL(@DrivingHours, 8.00);   -- чиглэл бүртгэлгүй бол нэг ээлж

        DECLARE @CrewSize INT = CASE WHEN @CoDriverId IS NULL THEN 1 ELSE 2 END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Drivers AS d
            WHERE d.DriverId IN (@PrimaryDriverId, @CoDriverId)
              AND @DrivingHours / @CrewSize > d.MaxDailyDrivingHours
        )
        BEGIN
            SET @Msg = FORMATMESSAGE(
                '%s hours of driving shared by %d driver(s) exceeds a driver''s daily limit - add a co-driver.',
                CAST(@DrivingHours AS NVARCHAR(10)), @CrewSize);
            THROW 50038, @Msg, 1;
        END

        -- 4. Бичих: рейс -> экипаж -> жагсаалт -> төлөв
        DECLARE @TripSeq INT = NEXT VALUE FOR dbo.seq_TripNumber;
        DECLARE @TripNumber NVARCHAR(20) =
            N'TRP-' + RIGHT(N'00000' + CAST(@TripSeq AS NVARCHAR(10)), 5);

        INSERT INTO dbo.Trips
        (
            TripNumber, VehicleId, OriginTerminalId, DestinationTerminalId,
            ScheduledDeparture, ScheduledArrival, StartOdometerKm, Status
        )
        VALUES
        (
            @TripNumber, @VehicleId, @OriginTerminalId, @DestinationTerminalId,
            @ScheduledDeparture,
            DATEADD(MINUTE, CAST(@DrivingHours * 60 AS INT), @ScheduledDeparture),
            @VehicleOdometer, N'Dispatched'
        );

        SET @TripId = SCOPE_IDENTITY();

        INSERT INTO dbo.TripDrivers (TripId, DriverId, DriverRole)
        VALUES (@TripId, @PrimaryDriverId, N'Primary');

        IF @CoDriverId IS NOT NULL
            INSERT INTO dbo.TripDrivers (TripId, DriverId, DriverRole)
            VALUES (@TripId, @CoDriverId, N'CoDriver');

        -- Хүргэх хугацаа нь дөхсөн ачааг түрүүлж буулгана
        INSERT INTO dbo.TripShipments (TripId, ShipmentId, StopSequence, LegType, LoadedAt)
        SELECT @TripId,
               s.ShipmentId,
               ROW_NUMBER() OVER (ORDER BY s.PromisedDeliveryDate, s.ShipmentId),
               N'LineHaul',
               @ScheduledDeparture
        FROM dbo.Shipments AS s
        INNER JOIN @ShipmentIds AS x ON x.Id = s.ShipmentId;

        UPDATE dbo.Vehicles
        SET Status = N'OnTrip', UpdatedAt = SYSUTCDATETIME()
        WHERE VehicleId = @VehicleId;

        -- Хөдлөөгүй ачаа InTransit болно; trigger тус бүрийг audit хийнэ
        UPDATE s
        SET s.Status    = N'InTransit',
            s.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Shipments AS s
        INNER JOIN @ShipmentIds AS x ON x.Id = s.ShipmentId
        WHERE s.Status IN (N'Booked', N'PickedUp', N'Exception');

        COMMIT TRANSACTION;

        SELECT @TripId       AS TripId,
               @TripNumber   AS TripNumber,
               @LoadWeightKg AS LoadWeightKg,
               @MaxPayloadKg AS VehiclePayloadKg,
               CAST(100.0 * @LoadWeightKg / @MaxPayloadKg AS DECIMAL(5,2)) AS PayloadUtilisationPct,
               (SELECT COUNT(*) FROM @ShipmentIds) AS ShipmentsLoaded;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*
  usp_CompleteTrip - рейсийг хааж машиныг Available болгоно, үгүй бол машин үүрд OnTrip үлдэнэ.
  Нэг транзакц: рейс Completed, ачсан/буулгасан цаг, одометр; терминалдаа хүрсэн ачаа OutForDelivery,
  hub дамжлагын дундах ачаа InTransit хэвээр. Одометрийг CK_Trips_Odometer-оос өмнө шалгана.
*/
CREATE OR ALTER PROCEDURE dbo.usp_CompleteTrip
    @TripId          INT,
    @EndOdometerKm   INT,
    @ActualArrival   DATETIME2(0) = NULL,   -- өгөхгүй бол одоогийн цаг
    @ActualDeparture DATETIME2(0) = NULL,   -- бүртгэсэн цаг байхгүй үед; эс бол товлосон
    @FuelLitres      DECIMAL(9,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Msg NVARCHAR(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Status                NVARCHAR(20),
                @VehicleId             INT,
                @StartOdometerKm       INT,
                @ScheduledDeparture    DATETIME2(0),
                @RecordedDeparture     DATETIME2(0),
                @DestinationTerminalId INT,
                @TripNumber            NVARCHAR(20);

        SELECT @Status                = t.Status,
               @VehicleId             = t.VehicleId,
               @StartOdometerKm       = t.StartOdometerKm,
               @ScheduledDeparture    = t.ScheduledDeparture,
               @RecordedDeparture     = t.ActualDeparture,
               @DestinationTerminalId = t.DestinationTerminalId,
               @TripNumber            = t.TripNumber
        FROM dbo.Trips AS t WITH (UPDLOCK, ROWLOCK)
        WHERE t.TripId = @TripId;

        IF @Status IS NULL
        BEGIN
            SET @Msg = FORMATMESSAGE('Trip %d does not exist.', @TripId);
            THROW 50070, @Msg, 1;
        END

        IF @Status NOT IN (N'Dispatched', N'InProgress')
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Only a Dispatched or InProgress trip can be completed (trip %s is %s).',
                @TripNumber, @Status);
            THROW 50071, @Msg, 1;
        END

        SET @ActualDeparture = COALESCE(@RecordedDeparture, @ActualDeparture, @ScheduledDeparture);
        SET @ActualArrival   = ISNULL(@ActualArrival, CAST(SYSUTCDATETIME() AS DATETIME2(0)));

        IF @EndOdometerKm < ISNULL(@StartOdometerKm, 0)
        BEGIN
            SET @Msg = FORMATMESSAGE('End odometer %d km is below the start reading of %d km.',
                                     @EndOdometerKm, ISNULL(@StartOdometerKm, 0));
            THROW 50072, @Msg, 1;
        END

        IF @ActualArrival < @ActualDeparture
            THROW 50073, 'The arrival time cannot be earlier than the departure time.', 1;

        UPDATE dbo.Trips
        SET Status          = N'Completed',
            ActualDeparture = @ActualDeparture,
            ActualArrival   = @ActualArrival,
            EndOdometerKm   = @EndOdometerKm,
            FuelLitres      = ISNULL(@FuelLitres, FuelLitres),
            UpdatedAt       = SYSUTCDATETIME()
        WHERE TripId = @TripId;

        -- Гарахад ачсан, ирэхэд буулгасан (CK_TripShipments_LoadOrder шаарддаг)
        UPDATE dbo.TripShipments
        SET LoadedAt   = @ActualDeparture,
            UnloadedAt = @ActualArrival
        WHERE TripId = @TripId;

        UPDATE dbo.Vehicles
        SET Status     = N'Available',
            OdometerKm = CASE WHEN @EndOdometerKm > OdometerKm THEN @EndOdometerKm ELSE OdometerKm END,
            UpdatedAt  = SYSUTCDATETIME()
        WHERE VehicleId = @VehicleId;

        -- Терминалдаа хүрсэн ачаа хүргэлтэд гарна, дамжлагынх InTransit хэвээр
        UPDATE s
        SET s.Status    = N'OutForDelivery',
            s.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Shipments AS s
        INNER JOIN dbo.TripShipments AS ts ON ts.ShipmentId = s.ShipmentId
        INNER JOIN dbo.Lanes         AS l  ON l.LaneId      = s.LaneId
        WHERE ts.TripId = @TripId
          AND s.Status  = N'InTransit'
          AND l.DestinationTerminalId = @DestinationTerminalId;

        COMMIT TRANSACTION;

        SELECT
            @TripId                                                       AS TripId,
            @TripNumber                                                   AS TripNumber,
            N'Completed'                                                  AS Status,
            @EndOdometerKm - ISNULL(@StartOdometerKm, @EndOdometerKm)     AS KmDriven,
            CAST(DATEDIFF(MINUTE, @ActualDeparture, @ActualArrival) / 60.0 AS DECIMAL(6,2)) AS DurationHours,
            (SELECT COUNT(*) FROM dbo.TripShipments ts
             INNER JOIN dbo.Shipments s ON s.ShipmentId = ts.ShipmentId
             WHERE ts.TripId = @TripId AND s.Status = N'OutForDelivery') AS ShipmentsOutForDelivery,
            (SELECT COUNT(*) FROM dbo.TripShipments ts
             INNER JOIN dbo.Shipments s ON s.ShipmentId = ts.ShipmentId
             WHERE ts.TripId = @TripId AND s.Status = N'InTransit')      AS ShipmentsAwaitingTransfer;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*
  usp_GenerateCustomerInvoice - хугацаанд хүргэгдсэн, нэхэмжлээгүй ачаанд нэхэмжлэх гаргана.
  Header-ийг 0-ээр бичээд мөрүүдийг оруулж, дүнг мөрүүдээс бодно, тэгэхээр нийт дүн зөрөхгүй.
  Давхар нэхэмжлэхээс UQ_InvoiceLines_Shipment хамгаална (зэрэг 2 удаа ажилласан ч).
*/
CREATE OR ALTER PROCEDURE dbo.usp_GenerateCustomerInvoice
    @CustomerId  INT,
    @PeriodStart DATE,
    @PeriodEnd   DATE,
    @IssueDate   DATE = NULL,
    @InvoiceId   INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IssueDate = ISNULL(@IssueDate, CAST(SYSUTCDATETIME() AS DATE));

    DECLARE @Msg NVARCHAR(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @PeriodEnd < @PeriodStart
            THROW 50040, 'The period end cannot be before the period start.', 1;

        DECLARE @PaymentTermsDays SMALLINT =
        (
            SELECT PaymentTermsDays FROM dbo.Customers WHERE CustomerId = @CustomerId
        );

        IF @PaymentTermsDays IS NULL
        BEGIN
            SET @Msg = FORMATMESSAGE('Customer %d does not exist.', @CustomerId);
            THROW 50041, @Msg, 1;
        END

        -- Нэхэмжлэх ачааг эхлээд цуглуулна (тоолох, дахин ашиглахад)
        DECLARE @Billable TABLE
        (
            ShipmentId     BIGINT        NOT NULL PRIMARY KEY,
            TrackingNumber NVARCHAR(20)  NOT NULL,
            PickupDate     DATE          NOT NULL,
            NetAmount      DECIMAL(12,2) NOT NULL,
            LaneName       NVARCHAR(100) NOT NULL
        );

        INSERT INTO @Billable (ShipmentId, TrackingNumber, PickupDate, NetAmount, LaneName)
        SELECT s.ShipmentId,
               s.TrackingNumber,
               s.PickupDate,
               s.FreightCharge + s.SurchargeAmount,   -- татваргүй; НӨАТ-ыг мөр бүрт нэмнэ
               ot.TerminalCode + N' -> ' + dt.TerminalCode
        FROM dbo.Shipments AS s
        INNER JOIN dbo.Lanes     AS l  ON l.LaneId      = s.LaneId
        INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
        INNER JOIN dbo.Terminals AS dt ON dt.TerminalId = l.DestinationTerminalId
        WHERE s.CustomerId = @CustomerId
          AND s.Status     = N'Delivered'
          AND s.ActualDeliveryDate BETWEEN @PeriodStart AND @PeriodEnd
          AND NOT EXISTS (SELECT 1 FROM dbo.InvoiceLines AS il
                          WHERE il.ShipmentId = s.ShipmentId);

        IF NOT EXISTS (SELECT 1 FROM @Billable)
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Customer %d has no uninvoiced delivered shipments in that period.', @CustomerId);
            THROW 50042, @Msg, 1;
        END

        DECLARE @InvSeq INT = NEXT VALUE FOR dbo.seq_InvoiceNumber;
        DECLARE @InvoiceNumber NVARCHAR(20) =
              N'INV-' + CAST(YEAR(@IssueDate) AS NVARCHAR(4))
            + N'-' + RIGHT(N'00000' + CAST(@InvSeq AS NVARCHAR(10)), 5);

        INSERT INTO dbo.Invoices
            (InvoiceNumber, CustomerId, IssueDate, DueDate, Status, Subtotal, TaxAmount, Notes)
        VALUES
            (@InvoiceNumber, @CustomerId, @IssueDate,
             DATEADD(DAY, @PaymentTermsDays, @IssueDate),
             N'Draft', 0, 0,
             FORMATMESSAGE('Freight services %s to %s.',
                           CONVERT(NVARCHAR(10), @PeriodStart, 23),
                           CONVERT(NVARCHAR(10), @PeriodEnd,   23)));

        SET @InvoiceId = SCOPE_IDENTITY();

        INSERT INTO dbo.InvoiceLines
            (InvoiceId, ShipmentId, LineNumber, Description, NetAmount, TaxRate)
        SELECT @InvoiceId,
               b.ShipmentId,
               ROW_NUMBER() OVER (ORDER BY b.PickupDate, b.ShipmentId),
               FORMATMESSAGE('%s  %s  (picked up %s)',
                             b.TrackingNumber, b.LaneName,
                             CONVERT(NVARCHAR(10), b.PickupDate, 23)),
               b.NetAmount,
               0.2000
        FROM @Billable AS b;

        -- Нийт дүнг мөрүүдээс бодно, гаднаас авахгүй
        UPDATE i
        SET i.Subtotal  = t.NetTotal,
            i.TaxAmount = t.TaxTotal,
            i.Status    = N'Issued',
            i.UpdatedAt = SYSUTCDATETIME()
        FROM dbo.Invoices AS i
        CROSS APPLY
        (
            SELECT SUM(il.NetAmount) AS NetTotal,
                   SUM(il.TaxAmount) AS TaxTotal
            FROM dbo.InvoiceLines AS il
            WHERE il.InvoiceId = i.InvoiceId
        ) AS t
        WHERE i.InvoiceId = @InvoiceId;

        COMMIT TRANSACTION;

        SELECT i.InvoiceId, i.InvoiceNumber, i.CustomerId, i.IssueDate, i.DueDate,
               i.Status, i.Subtotal, i.TaxAmount, i.TotalAmount,
               (SELECT COUNT(*) FROM dbo.InvoiceLines WHERE InvoiceId = i.InvoiceId) AS LineCount
        FROM dbo.Invoices AS i
        WHERE i.InvoiceId = @InvoiceId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*
  usp_RecordPayment - нэхэмжлэх дээр төлбөр бүртгэнэ. Нэхэмжлэхийг UPDLOCK-той уншдаг:
  2 ажилтан ижил үлдэгдэл хараад илүү төлүүлэхгүй. Paid / PartiallyPaid төлөвийг
  TR_Payments_MaintainInvoiceStatus тавьдаг, тиймээс гаднаас оруулсан төлбөрт ч зөв.
*/
CREATE OR ALTER PROCEDURE dbo.usp_RecordPayment
    @InvoiceId       INT,
    @PaymentMethodId INT,
    @Amount          DECIMAL(12,2),
    @ReferenceNumber NVARCHAR(50),
    @PaidOn          DATE = NULL,
    @ReceivedBy      INT  = NULL,
    @PaymentId       INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @PaidOn = ISNULL(@PaidOn, CAST(SYSUTCDATETIME() AS DATE));

    DECLARE @Msg NVARCHAR(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @InvoiceStatus NVARCHAR(15), @InvoiceTotal DECIMAL(12,2);

        SELECT @InvoiceStatus = i.Status,
               @InvoiceTotal  = i.TotalAmount
        FROM dbo.Invoices AS i WITH (UPDLOCK, ROWLOCK)
        WHERE i.InvoiceId = @InvoiceId;

        IF @InvoiceStatus IS NULL
        BEGIN
            SET @Msg = FORMATMESSAGE('Invoice %d does not exist.', @InvoiceId);
            THROW 50050, @Msg, 1;
        END

        IF @InvoiceStatus IN (N'Draft', N'Cancelled')
        BEGIN
            SET @Msg = FORMATMESSAGE('Cannot take payment against a %s invoice.', @InvoiceStatus);
            THROW 50051, @Msg, 1;
        END

        IF @Amount <= 0
            THROW 50052, 'Payment amount must be greater than zero.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.PaymentMethods
                       WHERE PaymentMethodId = @PaymentMethodId AND IsActive = 1)
            THROW 50053, 'The payment method does not exist or is not active.', 1;

        DECLARE @AlreadyPaid DECIMAL(12,2) =
        (
            SELECT ISNULL(SUM(p.Amount), 0) FROM dbo.Payments AS p WHERE p.InvoiceId = @InvoiceId
        );
        DECLARE @Balance DECIMAL(12,2) = @InvoiceTotal - @AlreadyPaid;

        IF @Amount > @Balance
        BEGIN
            SET @Msg = FORMATMESSAGE(
                'Payment of %s exceeds the outstanding balance of %s on invoice %d.',
                CAST(@Amount  AS NVARCHAR(30)),
                CAST(@Balance AS NVARCHAR(30)), @InvoiceId);
            THROW 50054, @Msg, 1;
        END

        INSERT INTO dbo.Payments
            (InvoiceId, PaymentMethodId, PaidOn, Amount, ReferenceNumber, ReceivedBy)
        VALUES
            (@InvoiceId, @PaymentMethodId, @PaidOn, @Amount, @ReferenceNumber, @ReceivedBy);

        SET @PaymentId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT @PaymentId                  AS PaymentId,
               @InvoiceId                  AS InvoiceId,
               @Amount                     AS AmountPaid,
               @Balance - @Amount          AS RemainingBalance,
               (SELECT Status FROM dbo.Invoices WHERE InvoiceId = @InvoiceId) AS InvoiceStatus,
               dbo.fn_CustomerOutstandingBalance
               (
                   (SELECT CustomerId FROM dbo.Invoices WHERE InvoiceId = @InvoiceId)
               )                           AS CustomerOutstandingBalance;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*
  usp_GetCustomerShipments - порталд зориулсан хуудаслалттай хайлт, шүүлтүүр бүр заавал биш.
  OPTION (RECOMPILE): ганц cached plan шүүлтүүрийн бүх хослолд муу тохирдог тул дуудлага бүрт compile.
  @TotalRows-ийг OUTPUT-оор буцаана, хоёр дахь round trip хэрэггүй.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerShipments
    @CustomerId INT,
    @FromDate   DATE         = NULL,
    @ToDate     DATE         = NULL,
    @Status     NVARCHAR(20) = NULL,
    @PageNumber INT          = 1,
    @PageSize   INT          = 25,
    @TotalRows  INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerId = @CustomerId)
    BEGIN
        DECLARE @Msg NVARCHAR(200) = FORMATMESSAGE('Customer %d does not exist.', @CustomerId);
        THROW 50011, @Msg, 1;
    END

    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize   < 1 SET @PageSize   = 25;
    IF @PageSize > 200 SET @PageSize   = 200;   -- хэт том хуудаснаас сэргийлнэ

    SELECT @TotalRows = COUNT(*)
    FROM dbo.fn_GetCustomerShipments(@CustomerId, @FromDate, @ToDate) AS s
    WHERE (@Status IS NULL OR s.Status = @Status)
    OPTION (RECOMPILE);

    SELECT
        s.ShipmentId,
        s.TrackingNumber,
        s.Status,
        s.OriginTerminal,
        s.DestinationTerminal,
        s.ServiceCode,
        s.CategoryName,
        s.PickupDate,
        s.PromisedDeliveryDate,
        s.ActualDeliveryDate,
        s.TotalWeightKg,
        s.TotalAmount,
        s.DeliveryPerformance,
        s.DaysLate,
        s.BillingStatus,
        s.InvoiceNumber
    FROM dbo.fn_GetCustomerShipments(@CustomerId, @FromDate, @ToDate) AS s
    WHERE (@Status IS NULL OR s.Status = @Status)
    ORDER BY s.PickupDate DESC, s.ShipmentId DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY
    OPTION (RECOMPILE);
END;
GO

/*
  usp_GenerateMonthlyRevenueReport - сарын тайлан, 4 result set: гол үзүүлэлт (өнгөрсөн оны мөн сартай),
  ангиллаар орлого, топ N харилцагч, чиглэлийн гүйцэтгэл. Зөвхөн уншдаг тул транзакцгүй.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GenerateMonthlyRevenueReport
    @Year         INT,
    @Month        INT,
    @TopCustomers INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @Month NOT BETWEEN 1 AND 12
        THROW 50060, 'Month must be between 1 and 12.', 1;

    IF @Year NOT BETWEEN 2000 AND 2100
        THROW 50060, 'Year must be between 2000 and 2100.', 1;

    DECLARE @PeriodStart DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @PeriodEnd   DATE = EOMONTH(@PeriodStart);
    DECLARE @PriorStart  DATE = DATEADD(YEAR, -1, @PeriodStart);
    DECLARE @PriorEnd    DATE = EOMONTH(@PriorStart);

    -- 1. Гол үзүүлэлтүүд, энэ сар vs өнгөрсөн оны мөн сар
    SELECT
        @PeriodStart                                    AS PeriodStart,
        @PeriodEnd                                      AS PeriodEnd,
        cur.ShipmentCount,
        cur.ActiveCustomers,
        cur.TotalRevenue,
        cur.TotalWeightKg,
        CAST(cur.AverageShipmentValue AS DECIMAL(12,2)) AS AverageShipmentValue,
        cur.OnTimePercentage,
        pri.TotalRevenue                                AS PriorYearRevenue,
        cur.TotalRevenue - pri.TotalRevenue             AS YoYRevenueChange,
        CAST(100.0 * (cur.TotalRevenue - pri.TotalRevenue)
             / NULLIF(pri.TotalRevenue, 0) AS DECIMAL(8,2)) AS YoYGrowthPct
    FROM
    (
        SELECT COUNT(*)                     AS ShipmentCount,
               COUNT(DISTINCT s.CustomerId) AS ActiveCustomers,
               ISNULL(SUM(s.TotalAmount),0) AS TotalRevenue,
               ISNULL(SUM(s.TotalWeightKg),0) AS TotalWeightKg,
               ISNULL(AVG(s.TotalAmount),0) AS AverageShipmentValue,
               CAST(100.0 * AVG(CASE WHEN s.ActualDeliveryDate IS NULL THEN NULL
                                     WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate THEN 1.0
                                     ELSE 0.0 END) AS DECIMAL(5,2)) AS OnTimePercentage
        FROM dbo.Shipments AS s
        WHERE s.PickupDate BETWEEN @PeriodStart AND @PeriodEnd
          AND s.Status <> N'Cancelled'
    ) AS cur
    CROSS JOIN
    (
        SELECT ISNULL(SUM(s.TotalAmount), 0) AS TotalRevenue
        FROM dbo.Shipments AS s
        WHERE s.PickupDate BETWEEN @PriorStart AND @PriorEnd
          AND s.Status <> N'Cancelled'
    ) AS pri;

    -- 2. Ачааны ангиллаар орлого
    WITH CategoryMonth AS
    (
        SELECT cc.CategoryCode,
               cc.CategoryName,
               COUNT(*)             AS ShipmentCount,
               SUM(s.TotalAmount)   AS TotalRevenue,
               SUM(s.TotalWeightKg) AS TotalWeightKg
        FROM dbo.Shipments AS s
        INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
        WHERE s.PickupDate BETWEEN @PeriodStart AND @PeriodEnd
          AND s.Status <> N'Cancelled'
        GROUP BY cc.CategoryCode, cc.CategoryName
    )
    SELECT CategoryCode,
           CategoryName,
           ShipmentCount,
           TotalRevenue,
           TotalWeightKg,
           CAST(100.0 * TotalRevenue / NULLIF(SUM(TotalRevenue) OVER (), 0)
                AS DECIMAL(5,2))                          AS RevenueSharePct,
           DENSE_RANK() OVER (ORDER BY TotalRevenue DESC) AS RevenueRank
    FROM CategoryMonth
    ORDER BY TotalRevenue DESC;

    -- 3. Тухайн сарын топ харилцагчид
    SELECT TOP (@TopCustomers)
           c.CustomerCode,
           c.LegalName,
           COUNT(*)                                     AS ShipmentCount,
           SUM(s.TotalAmount)                           AS TotalRevenue,
           CAST(AVG(s.TotalAmount) AS DECIMAL(12,2))    AS AverageShipmentValue,
           CAST(100.0 * SUM(s.TotalAmount) / NULLIF(SUM(SUM(s.TotalAmount)) OVER (), 0)
                AS DECIMAL(5,2))                        AS ShareOfMonthPct,
           RANK() OVER (ORDER BY SUM(s.TotalAmount) DESC) AS RevenueRank
    FROM dbo.Shipments AS s
    INNER JOIN dbo.Customers AS c ON c.CustomerId = s.CustomerId
    WHERE s.PickupDate BETWEEN @PeriodStart AND @PeriodEnd
      AND s.Status <> N'Cancelled'
    GROUP BY c.CustomerCode, c.LegalName
    ORDER BY TotalRevenue DESC;

    -- 4. Тухайн сарын чиглэлүүдийн гүйцэтгэл
    SELECT ot.TerminalCode + N' -> ' + dt.TerminalCode  AS Lane,
           l.DistanceKm,
           COUNT(*)                                     AS ShipmentCount,
           SUM(s.TotalAmount)                           AS TotalRevenue,
           CAST(SUM(s.TotalAmount) / l.DistanceKm AS DECIMAL(12,2)) AS RevenuePerKm,
           CAST(100.0 * AVG(CASE WHEN s.ActualDeliveryDate IS NULL THEN NULL
                                 WHEN s.ActualDeliveryDate <= s.PromisedDeliveryDate THEN 1.0
                                 ELSE 0.0 END) AS DECIMAL(5,2))     AS OnTimePercentage
    FROM dbo.Shipments AS s
    INNER JOIN dbo.Lanes     AS l  ON l.LaneId      = s.LaneId
    INNER JOIN dbo.Terminals AS ot ON ot.TerminalId = l.OriginTerminalId
    INNER JOIN dbo.Terminals AS dt ON dt.TerminalId = l.DestinationTerminalId
    WHERE s.PickupDate BETWEEN @PeriodStart AND @PeriodEnd
      AND s.Status <> N'Cancelled'
    GROUP BY ot.TerminalCode, dt.TerminalCode, l.DistanceKm
    ORDER BY TotalRevenue DESC;
END;
GO

DECLARE @ProcCount INT =
(
    SELECT COUNT(*) FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo')
);
PRINT 'Stored procedures created: ' + CAST(@ProcCount AS VARCHAR(10)) + ' (expected 8)';
GO
