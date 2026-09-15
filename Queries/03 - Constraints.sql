/*
  NordFreight Logistics -- 03 - Хязгаарлалтууд
  FK, UNIQUE, CHECK хязгаарлалтууд.
  CASCADE зөвхөн эцэг мөргүйгээр утгагүй мөрүүдэд
  (контакт, ачаа бараа, жолооч г.м).
  Бусад нь NO ACTION: түүхтэй мөрийг устгуулахгүй.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1-р хэсэг - Газар */

ALTER TABLE dbo.Countries ADD
    CONSTRAINT UQ_Countries_IsoCode      UNIQUE (IsoCode),
    CONSTRAINT UQ_Countries_CountryName  UNIQUE (CountryName),
    CONSTRAINT CK_Countries_IsoCode      CHECK (IsoCode NOT LIKE '%[^A-Za-z]%'),
    CONSTRAINT CK_Countries_CurrencyCode CHECK (CurrencyCode NOT LIKE '%[^A-Za-z]%');
GO

ALTER TABLE dbo.Cities ADD
    CONSTRAINT FK_Cities_Countries FOREIGN KEY (CountryId)
        REFERENCES dbo.Countries (CountryId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    -- Хотын нэр давтагдаж болох тул улс+бүс+нэрээр unique.
    CONSTRAINT UQ_Cities_Country_Region_Name UNIQUE (CountryId, Region, CityName),
    CONSTRAINT CK_Cities_CityName CHECK (LEN(LTRIM(RTRIM(CityName))) > 0);
GO

ALTER TABLE dbo.Addresses ADD
    CONSTRAINT FK_Addresses_Cities FOREIGN KEY (CityId)
        REFERENCES dbo.Cities (CityId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Addresses_Latitude   CHECK (Latitude  IS NULL OR Latitude  BETWEEN  -90 AND  90),
    CONSTRAINT CK_Addresses_Longitude  CHECK (Longitude IS NULL OR Longitude BETWEEN -180 AND 180),
    -- Координат хагас дутуу байж болохгүй: хоёулаа эсвэл аль нь ч биш.
    CONSTRAINT CK_Addresses_GeoPair    CHECK ((Latitude IS NULL     AND Longitude IS NULL)
                                           OR (Latitude IS NOT NULL AND Longitude IS NOT NULL)),
    CONSTRAINT CK_Addresses_PostalCode CHECK (LEN(LTRIM(RTRIM(PostalCode))) > 0);
GO

/* 2-р хэсэг - Худалдаа / Харилцагчид */

ALTER TABLE dbo.Customers ADD
    CONSTRAINT FK_Customers_Addresses FOREIGN KEY (BillingAddressId)
        REFERENCES dbo.Addresses (AddressId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Customers_CodeFormat   CHECK (CustomerCode LIKE 'CUS-[0-9][0-9][0-9][0-9]'),
    CONSTRAINT UQ_Customers_Code         UNIQUE (CustomerCode),
    CONSTRAINT UQ_Customers_TaxNumber    UNIQUE (TaxNumber),
    CONSTRAINT CK_Customers_CreditLimit  CHECK (CreditLimit >= 0),
    CONSTRAINT CK_Customers_PaymentTerms CHECK (PaymentTermsDays BETWEEN 0 AND 120),
    CONSTRAINT CK_Customers_OnboardedOn  CHECK (OnboardedOn >= '2000-01-01');
GO

ALTER TABLE dbo.CustomerContacts ADD
    CONSTRAINT FK_CustomerContacts_Customers FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers (CustomerId) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT UQ_CustomerContacts_Customer_Email UNIQUE (CustomerId, Email),
    CONSTRAINT CK_CustomerContacts_Email CHECK (Email LIKE '%_@_%._%');
GO

/* 3-р хэсэг - Сүлжээ / Терминал (Зогсоол) / Ажилтнууд */

ALTER TABLE dbo.Terminals ADD
    CONSTRAINT FK_Terminals_Addresses FOREIGN KEY (AddressId)
        REFERENCES dbo.Addresses (AddressId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Terminals_CodeFormat   CHECK (TerminalCode NOT LIKE '%[^A-Za-z]%'),
    CONSTRAINT UQ_Terminals_Code         UNIQUE (TerminalCode),
    CONSTRAINT UQ_Terminals_TerminalName UNIQUE (TerminalName),
    -- FK дээр UNIQUE тул нэг хаягт нэг л терминал (1:1).
    CONSTRAINT UQ_Terminals_AddressId    UNIQUE (AddressId),
    CONSTRAINT CK_Terminals_Capacity     CHECK (CapacityPallets > 0);
GO

ALTER TABLE dbo.Employees ADD
    CONSTRAINT FK_Employees_Terminals FOREIGN KEY (HomeTerminalId)
        REFERENCES dbo.Terminals (TerminalId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    -- Өөрийгөө заадаг FK cascade хийж чадахгүй.
    CONSTRAINT FK_Employees_Manager FOREIGN KEY (ManagerId)
        REFERENCES dbo.Employees (EmployeeId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_Employees_EmployeeCode UNIQUE (EmployeeCode),
    CONSTRAINT UQ_Employees_Email        UNIQUE (Email),
    CONSTRAINT CK_Employees_Email        CHECK (Email LIKE '%_@_%._%'),
    CONSTRAINT CK_Employees_JobTitle     CHECK (JobTitle IN
        (N'Driver', N'Dispatcher', N'Terminal Manager', N'Operations Manager',
         N'Billing Clerk', N'Fleet Technician', N'Managing Director')),
    CONSTRAINT CK_Employees_Termination  CHECK (TerminationDate IS NULL
                                             OR TerminationDate >= HireDate),
    CONSTRAINT CK_Employees_NotOwnManager CHECK (ManagerId IS NULL OR ManagerId <> EmployeeId);
GO

ALTER TABLE dbo.Drivers ADD
    -- PK + FK нэг баганад = Employees-тэй 1:1.
    CONSTRAINT FK_Drivers_Employees FOREIGN KEY (DriverId)
        REFERENCES dbo.Employees (EmployeeId) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT UQ_Drivers_LicenceNumber UNIQUE (LicenceNumber),
    CONSTRAINT CK_Drivers_LicenceClass  CHECK (LicenceClass IN ('C', 'C1', 'CE', 'D')),
    CONSTRAINT CK_Drivers_LicenceDates  CHECK (LicenceExpiresOn > LicenceIssuedOn),
    CONSTRAINT CK_Drivers_DrivingHours  CHECK (MaxDailyDrivingHours BETWEEN 1.00 AND 11.00);
GO

ALTER TABLE dbo.VehicleTypes ADD
    CONSTRAINT UQ_VehicleTypes_TypeCode  UNIQUE (TypeCode),
    CONSTRAINT UQ_VehicleTypes_TypeName  UNIQUE (TypeName),
    CONSTRAINT CK_VehicleTypes_Payload   CHECK (MaxPayloadKg > 0),
    CONSTRAINT CK_VehicleTypes_Volume    CHECK (MaxVolumeM3 > 0),
    CONSTRAINT CK_VehicleTypes_AxleCount CHECK (AxleCount BETWEEN 2 AND 8),
    CONSTRAINT CK_VehicleTypes_Licence   CHECK (RequiredLicenceClass IN ('C', 'C1', 'CE'));
GO

ALTER TABLE dbo.Vehicles ADD
    CONSTRAINT FK_Vehicles_VehicleTypes FOREIGN KEY (VehicleTypeId)
        REFERENCES dbo.VehicleTypes (VehicleTypeId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Vehicles_Terminals FOREIGN KEY (HomeTerminalId)
        REFERENCES dbo.Terminals (TerminalId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_Vehicles_PlateNumber UNIQUE (PlateNumber),
    CONSTRAINT UQ_Vehicles_VIN         UNIQUE (VIN),
    -- VIN-д I, O, Q үсэг ордоггүй.
    CONSTRAINT CK_Vehicles_VIN         CHECK (VIN NOT LIKE '%[^A-HJ-NPR-Z0-9]%'),
    CONSTRAINT CK_Vehicles_ModelYear   CHECK (ModelYear BETWEEN 1990 AND 2100),
    CONSTRAINT CK_Vehicles_OdometerKm  CHECK (OdometerKm >= 0),
    CONSTRAINT CK_Vehicles_Status      CHECK (Status IN
        (N'Available', N'OnTrip', N'InMaintenance', N'Retired'));
GO

ALTER TABLE dbo.MaintenanceRecords ADD
    -- NO ACTION: засварын зардал санхүүгийн түүх тул үлдэнэ.
    CONSTRAINT FK_MaintenanceRecords_Vehicles FOREIGN KEY (VehicleId)
        REFERENCES dbo.Vehicles (VehicleId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_MaintenanceRecords_Type CHECK (MaintenanceType IN
        (N'Scheduled', N'Repair', N'Inspection', N'TyreChange', N'Bodywork', N'Recall')),
    CONSTRAINT CK_MaintenanceRecords_Odometer CHECK (OdometerKm >= 0),
    CONSTRAINT CK_MaintenanceRecords_Costs    CHECK (LabourCost >= 0 AND PartsCost >= 0),
    CONSTRAINT CK_MaintenanceRecords_DownTime CHECK (DownTimeHours >= 0);
GO

/* 4-р хэсэг - Үйлчилгээ, чиглэл, үнэ */

ALTER TABLE dbo.ServiceLevels ADD
    CONSTRAINT UQ_ServiceLevels_ServiceCode UNIQUE (ServiceCode),
    CONSTRAINT UQ_ServiceLevels_ServiceName UNIQUE (ServiceName),
    CONSTRAINT CK_ServiceLevels_TransitDays CHECK (MaxTransitDays BETWEEN 1 AND 30),
    CONSTRAINT CK_ServiceLevels_Multiplier  CHECK (PriceMultiplier BETWEEN 0.500 AND 5.000);
GO

ALTER TABLE dbo.CargoCategories ADD
    CONSTRAINT UQ_CargoCategories_CategoryCode UNIQUE (CategoryCode),
    CONSTRAINT UQ_CargoCategories_CategoryName UNIQUE (CategoryName),
    CONSTRAINT CK_CargoCategories_Surcharge    CHECK (HandlingSurchargeRate BETWEEN 0 AND 1),
    CONSTRAINT CK_CargoCategories_MaxValue     CHECK (MaxDeclaredValue IS NULL
                                                   OR MaxDeclaredValue > 0);
GO

ALTER TABLE dbo.Lanes ADD
    CONSTRAINT FK_Lanes_OriginTerminal FOREIGN KEY (OriginTerminalId)
        REFERENCES dbo.Terminals (TerminalId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Lanes_DestinationTerminal FOREIGN KEY (DestinationTerminalId)
        REFERENCES dbo.Terminals (TerminalId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    -- Нэг зүгтэй: A->B, B->A тусдаа мөр, өөр үнэтэй байж болно.
    CONSTRAINT UQ_Lanes_OriginDestination UNIQUE (OriginTerminalId, DestinationTerminalId),
    CONSTRAINT CK_Lanes_DistinctTerminals CHECK (OriginTerminalId <> DestinationTerminalId),
    CONSTRAINT CK_Lanes_DistanceKm        CHECK (DistanceKm > 0),
    CONSTRAINT CK_Lanes_DrivingHours      CHECK (EstimatedDrivingHours > 0),
    -- Дундаж хурд 20-110 km/h; хуваалт биш үржүүлэлт тул 0-д хуваахгүй.
    CONSTRAINT CK_Lanes_PlausibleSpeed    CHECK (DistanceKm BETWEEN EstimatedDrivingHours * 20
                                                              AND EstimatedDrivingHours * 110);
GO

ALTER TABLE dbo.LaneRates ADD
    CONSTRAINT FK_LaneRates_Lanes FOREIGN KEY (LaneId)
        REFERENCES dbo.Lanes (LaneId) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_LaneRates_ServiceLevels FOREIGN KEY (ServiceLevelId)
        REFERENCES dbo.ServiceLevels (ServiceLevelId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_LaneRates_Lane_Service_From UNIQUE (LaneId, ServiceLevelId, EffectiveFrom),
    CONSTRAINT CK_LaneRates_RatePerKg     CHECK (RatePerKg > 0),
    CONSTRAINT CK_LaneRates_MinimumCharge CHECK (MinimumCharge >= 0),
    CONSTRAINT CK_LaneRates_FuelSurcharge CHECK (FuelSurchargeRate BETWEEN 0 AND 1),
    CONSTRAINT CK_LaneRates_Period        CHECK (EffectiveTo IS NULL
                                               OR EffectiveTo > EffectiveFrom);
GO

/* 5-р хэсэг - Үйл ажиллагаа */

ALTER TABLE dbo.Shipments ADD
    CONSTRAINT FK_Shipments_Customers FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers (CustomerId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Shipments_Lanes FOREIGN KEY (LaneId)
        REFERENCES dbo.Lanes (LaneId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Shipments_ServiceLevels FOREIGN KEY (ServiceLevelId)
        REFERENCES dbo.ServiceLevels (ServiceLevelId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Shipments_CargoCategories FOREIGN KEY (CargoCategoryId)
        REFERENCES dbo.CargoCategories (CargoCategoryId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Shipments_OriginAddress FOREIGN KEY (OriginAddressId)
        REFERENCES dbo.Addresses (AddressId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Shipments_DestinationAddress FOREIGN KEY (DestinationAddressId)
        REFERENCES dbo.Addresses (AddressId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_Shipments_TrackingNumber UNIQUE (TrackingNumber),
    CONSTRAINT CK_Shipments_TrackingFormat CHECK
        (TrackingNumber LIKE 'NF[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_Shipments_Status CHECK (Status IN
        (N'Booked', N'PickedUp', N'InTransit', N'OutForDelivery',
         N'Delivered', N'Cancelled', N'Exception')),
    CONSTRAINT CK_Shipments_Weight        CHECK (TotalWeightKg > 0),
    CONSTRAINT CK_Shipments_Volume        CHECK (TotalVolumeM3 > 0),
    CONSTRAINT CK_Shipments_DeclaredValue CHECK (DeclaredValue >= 0),
    CONSTRAINT CK_Shipments_Charges       CHECK (FreightCharge   >= 0
                                             AND SurchargeAmount >= 0
                                             AND TaxAmount       >= 0),
    CONSTRAINT CK_Shipments_PromiseAfterPickup  CHECK (PromisedDeliveryDate >= PickupDate),
    CONSTRAINT CK_Shipments_DeliveryAfterPickup CHECK (ActualDeliveryDate IS NULL
                                                    OR ActualDeliveryDate >= PickupDate),
    CONSTRAINT CK_Shipments_DistinctEndpoints   CHECK (OriginAddressId <> DestinationAddressId),
    -- Delivered бол ActualDeliveryDate заавал байна.
    CONSTRAINT CK_Shipments_DeliveredHasDate    CHECK (Status <> N'Delivered'
                                                    OR ActualDeliveryDate IS NOT NULL);
GO

ALTER TABLE dbo.ShipmentItems ADD
    CONSTRAINT FK_ShipmentItems_Shipments FOREIGN KEY (ShipmentId)
        REFERENCES dbo.Shipments (ShipmentId) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT UQ_ShipmentItems_Shipment_Line UNIQUE (ShipmentId, LineNumber),
    CONSTRAINT CK_ShipmentItems_LineNumber CHECK (LineNumber > 0),
    CONSTRAINT CK_ShipmentItems_Quantity   CHECK (Quantity > 0),
    CONSTRAINT CK_ShipmentItems_UnitWeight CHECK (UnitWeightKg > 0),
    CONSTRAINT CK_ShipmentItems_UnitVolume CHECK (UnitVolumeM3 > 0),
    CONSTRAINT CK_ShipmentItems_Packaging  CHECK (PackagingType IN
        (N'Pallet', N'Box', N'Crate', N'Drum', N'Bag', N'Roll'));
GO

ALTER TABLE dbo.ShipmentStatusHistory ADD
    CONSTRAINT FK_ShipmentStatusHistory_Shipments FOREIGN KEY (ShipmentId)
        REFERENCES dbo.Shipments (ShipmentId) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_ShipmentStatusHistory_Terminals FOREIGN KEY (TerminalId)
        REFERENCES dbo.Terminals (TerminalId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_ShipmentStatusHistory_NewStatus CHECK (NewStatus IN
        (N'Booked', N'PickedUp', N'InTransit', N'OutForDelivery',
         N'Delivered', N'Cancelled', N'Exception')),
    CONSTRAINT CK_ShipmentStatusHistory_Changed CHECK (OldStatus IS NULL
                                                    OR OldStatus <> NewStatus);
GO

ALTER TABLE dbo.Trips ADD
    CONSTRAINT FK_Trips_Vehicles FOREIGN KEY (VehicleId)
        REFERENCES dbo.Vehicles (VehicleId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Trips_OriginTerminal FOREIGN KEY (OriginTerminalId)
        REFERENCES dbo.Terminals (TerminalId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Trips_DestinationTerminal FOREIGN KEY (DestinationTerminalId)
        REFERENCES dbo.Terminals (TerminalId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Trips_NumberFormat CHECK (TripNumber LIKE 'TRP-[0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT UQ_Trips_Number     UNIQUE (TripNumber),
    CONSTRAINT CK_Trips_Status CHECK (Status IN
        (N'Planned', N'Dispatched', N'InProgress', N'Completed', N'Cancelled')),
    CONSTRAINT CK_Trips_Schedule  CHECK (ScheduledArrival > ScheduledDeparture),
    CONSTRAINT CK_Trips_Actuals   CHECK (ActualArrival IS NULL
                                      OR ActualDeparture IS NULL
                                      OR ActualArrival >= ActualDeparture),
    CONSTRAINT CK_Trips_Odometer  CHECK (EndOdometerKm IS NULL
                                      OR StartOdometerKm IS NULL
                                      OR EndOdometerKm >= StartOdometerKm),
    CONSTRAINT CK_Trips_FuelLitres        CHECK (FuelLitres IS NULL OR FuelLitres >= 0),
    CONSTRAINT CK_Trips_DistinctTerminals CHECK (OriginTerminalId <> DestinationTerminalId),
    -- Completed бол бодит хөдөлсөн, ирсэн цаг заавал байна.
    CONSTRAINT CK_Trips_CompletedHasActuals CHECK (Status <> N'Completed'
                                                OR (ActualDeparture IS NOT NULL
                                                AND ActualArrival   IS NOT NULL));
GO

ALTER TABLE dbo.TripDrivers ADD
    CONSTRAINT FK_TripDrivers_Trips FOREIGN KEY (TripId)
        REFERENCES dbo.Trips (TripId) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_TripDrivers_Drivers FOREIGN KEY (DriverId)
        REFERENCES dbo.Drivers (DriverId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_TripDrivers_Role CHECK (DriverRole IN (N'Primary', N'CoDriver'));
-- Рейс бүрт нэг Primary жолоочийг "04 - Indexes.sql"-ийн UX_TripDrivers_OnePrimary хянана.
GO

ALTER TABLE dbo.TripShipments ADD
    CONSTRAINT FK_TripShipments_Trips FOREIGN KEY (TripId)
        REFERENCES dbo.Trips (TripId) ON DELETE CASCADE ON UPDATE NO ACTION,
    -- NO ACTION: тээвэрлэгдсэн ачааг устгахгүй.
    CONSTRAINT FK_TripShipments_Shipments FOREIGN KEY (ShipmentId)
        REFERENCES dbo.Shipments (ShipmentId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_TripShipments_Trip_Stop UNIQUE (TripId, StopSequence),
    CONSTRAINT CK_TripShipments_StopSequence CHECK (StopSequence > 0),
    CONSTRAINT CK_TripShipments_LegType CHECK (LegType IN
        (N'Pickup', N'LineHaul', N'Delivery')),
    CONSTRAINT CK_TripShipments_LoadOrder CHECK (UnloadedAt IS NULL
                                              OR LoadedAt   IS NULL
                                              OR UnloadedAt >= LoadedAt);
GO

/* 6-р хэсэг - Төлбөр тооцоо */

ALTER TABLE dbo.Invoices ADD
    CONSTRAINT FK_Invoices_Customers FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers (CustomerId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_Invoices_InvoiceNumber UNIQUE (InvoiceNumber),
    CONSTRAINT CK_Invoices_NumberFormat  CHECK
        (InvoiceNumber LIKE 'INV-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_Invoices_Status CHECK (Status IN
        (N'Draft', N'Issued', N'PartiallyPaid', N'Paid', N'Overdue', N'Cancelled')),
    CONSTRAINT CK_Invoices_DueDate CHECK (DueDate >= IssueDate),
    CONSTRAINT CK_Invoices_Amounts CHECK (Subtotal >= 0 AND TaxAmount >= 0);
GO

ALTER TABLE dbo.InvoiceLines ADD
    CONSTRAINT FK_InvoiceLines_Invoices FOREIGN KEY (InvoiceId)
        REFERENCES dbo.Invoices (InvoiceId) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_InvoiceLines_Shipments FOREIGN KEY (ShipmentId)
        REFERENCES dbo.Shipments (ShipmentId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_InvoiceLines_Invoice_Line UNIQUE (InvoiceId, LineNumber),
    -- Гол дүрэм: нэг ачааг нэг л удаа нэхэмжилнэ, датабааз өөрөө хянана.
    CONSTRAINT UQ_InvoiceLines_Shipment UNIQUE (ShipmentId),
    CONSTRAINT CK_InvoiceLines_LineNumber CHECK (LineNumber > 0),
    CONSTRAINT CK_InvoiceLines_NetAmount  CHECK (NetAmount >= 0),
    CONSTRAINT CK_InvoiceLines_TaxRate    CHECK (TaxRate BETWEEN 0 AND 1);
GO

ALTER TABLE dbo.PaymentMethods ADD
    CONSTRAINT UQ_PaymentMethods_MethodCode UNIQUE (MethodCode),
    CONSTRAINT UQ_PaymentMethods_MethodName UNIQUE (MethodName);
GO

ALTER TABLE dbo.Payments ADD
    -- NO ACTION: төлбөртэй нэхэмжлэхийг устгахгүй.
    CONSTRAINT FK_Payments_Invoices FOREIGN KEY (InvoiceId)
        REFERENCES dbo.Invoices (InvoiceId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Payments_PaymentMethods FOREIGN KEY (PaymentMethodId)
        REFERENCES dbo.PaymentMethods (PaymentMethodId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Payments_Employees FOREIGN KEY (ReceivedBy)
        REFERENCES dbo.Employees (EmployeeId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    -- Нэг нэхэмжлэхэд ижил гүйлгээг давхар бүртгэхгүй.
    CONSTRAINT UQ_Payments_Invoice_Reference UNIQUE (InvoiceId, ReferenceNumber),
    CONSTRAINT CK_Payments_Amount CHECK (Amount > 0),
    CONSTRAINT CK_Payments_PaidOn CHECK (PaidOn >= '2000-01-01');
-- Төлбөр нэхэмжлэхээс хэтрэхгүйг "08 - Triggers.sql"-ийн TR_Payments_MaintainInvoiceStatus
-- хянана (хоёр хүснэгт харах тул CHECK болохгүй).
GO

DECLARE @FKCount    INT = (SELECT COUNT(*) FROM sys.foreign_keys);
DECLARE @CheckCount INT = (SELECT COUNT(*) FROM sys.check_constraints);
DECLARE @UqCount    INT = (SELECT COUNT(*) FROM sys.key_constraints WHERE type = 'UQ');
PRINT 'Foreign keys: ' + CAST(@FKCount AS VARCHAR(10))
    + ' | CHECK constraints: ' + CAST(@CheckCount AS VARCHAR(10))
    + ' | UNIQUE constraints: ' + CAST(@UqCount AS VARCHAR(10));
GO
