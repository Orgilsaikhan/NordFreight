/*
  NordFreight Logistics -- 04 - Индексүүд
  PK, UNIQUE-ийн индексийг давтаагүй; UQ индексийн эхний багана болсон FK-г ч.
  Хаягийн FK-г зориуд индексгүй: ачаагаар л уншдаг, хаяг устгагддаггүй.
  INCLUDE баганууд "10 - Queries.sql"-ийн тайлангийн query-г covering болгоно.
  Filtered индекс нээлттэй мөрийг жижиг байлгаж, бизнес дүрмийг хэрэгжүүлнэ.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* 1-р хэсэг - FK баганын индекс */

-- Cities.CountryId-г UQ_Cities_Country_Region_Name хамарсан тул индексгүй.
CREATE NONCLUSTERED INDEX IX_Addresses_CityId
    ON dbo.Addresses (CityId);
GO

CREATE NONCLUSTERED INDEX IX_Customers_BillingAddressId
    ON dbo.Customers (BillingAddressId);
GO

-- CustomerContacts.CustomerId-г UQ_CustomerContacts_Customer_Email хамарсан.
-- Terminals.AddressId-г UQ_Terminals_AddressId хамарсан.

CREATE NONCLUSTERED INDEX IX_Employees_HomeTerminalId
    ON dbo.Employees (HomeTerminalId);
GO

-- Менежерийн шатлалын recursive CTE-д зориулсан.
CREATE NONCLUSTERED INDEX IX_Employees_ManagerId
    ON dbo.Employees (ManagerId)
    INCLUDE (FirstName, LastName, JobTitle);
GO

CREATE NONCLUSTERED INDEX IX_Vehicles_VehicleTypeId
    ON dbo.Vehicles (VehicleTypeId);
GO

CREATE NONCLUSTERED INDEX IX_Vehicles_HomeTerminalId
    ON dbo.Vehicles (HomeTerminalId)
    INCLUDE (Status);
GO

-- UQ_Lanes_OriginDestination-д destination 2-р багана тул тусдаа индекс хэрэгтэй.
CREATE NONCLUSTERED INDEX IX_Lanes_DestinationTerminalId
    ON dbo.Lanes (DestinationTerminalId)
    INCLUDE (OriginTerminalId, DistanceKm);
GO

-- LaneRates.LaneId-г UQ_LaneRates_Lane_Service_From хамарсан.

CREATE NONCLUSTERED INDEX IX_TripDrivers_DriverId
    ON dbo.TripDrivers (DriverId)
    INCLUDE (DriverRole);
GO

CREATE NONCLUSTERED INDEX IX_TripShipments_ShipmentId
    ON dbo.TripShipments (ShipmentId)
    INCLUDE (StopSequence, LegType);
GO

CREATE NONCLUSTERED INDEX IX_Payments_PaymentMethodId
    ON dbo.Payments (PaymentMethodId);
GO

/* 2-р хэсэг - Өдөр тутмын хайлт */

-- Харилцагчийн "миний ачаанууд, шинэ нь эхэндээ" жагсаалтад зориулсан.
CREATE NONCLUSTERED INDEX IX_Shipments_Customer_PickupDate
    ON dbo.Shipments (CustomerId, PickupDate DESC)
    INCLUDE (Status, ServiceLevelId, TotalAmount, ActualDeliveryDate, PromisedDeliveryDate);
GO

-- Тайлангийн гол индекс: сар, ангилал, харилцагчаар орлого.
CREATE NONCLUSTERED INDEX IX_Shipments_PickupDate_Status
    ON dbo.Shipments (PickupDate, Status)
    INCLUDE (CustomerId, CargoCategoryId, LaneId, FreightCharge, TotalAmount);
GO

-- Чиглэлийн ашиг, цагтаа хүргэлт.
CREATE NONCLUSTERED INDEX IX_Shipments_Lane_Service
    ON dbo.Shipments (LaneId, ServiceLevelId)
    INCLUDE (PickupDate, PromisedDeliveryDate, ActualDeliveryDate, TotalWeightKg, TotalAmount);
GO

-- Ангиллын орлогын хувь, чиг хандлага.
CREATE NONCLUSTERED INDEX IX_Shipments_CargoCategory_PickupDate
    ON dbo.Shipments (CargoCategoryId, PickupDate)
    INCLUDE (TotalAmount, TotalWeightKg);
GO

-- Dispatch самбарт зөвхөн явж буй ачаа; filtered тул индекс жижигхэн хэвээр.
CREATE NONCLUSTERED INDEX IX_Shipments_Open
    ON dbo.Shipments (Status, PickupDate)
    INCLUDE (CustomerId, LaneId, TrackingNumber, TotalWeightKg)
    WHERE Status IN (N'Booked', N'PickedUp', N'InTransit', N'OutForDelivery');
GO

CREATE NONCLUSTERED INDEX IX_ShipmentStatusHistory_Shipment_ChangedAt
    ON dbo.ShipmentStatusHistory (ShipmentId, ChangedAt DESC)
    INCLUDE (OldStatus, NewStatus);
GO

CREATE NONCLUSTERED INDEX IX_Trips_Vehicle_ScheduledDeparture
    ON dbo.Trips (VehicleId, ScheduledDeparture DESC)
    INCLUDE (Status, ActualDeparture, ActualArrival);
GO

CREATE NONCLUSTERED INDEX IX_Trips_OriginTerminal_ScheduledDeparture
    ON dbo.Trips (OriginTerminalId, ScheduledDeparture)
    INCLUDE (DestinationTerminalId, Status);
GO

CREATE NONCLUSTERED INDEX IX_Trips_DestinationTerminalId
    ON dbo.Trips (DestinationTerminalId);
GO

/* 3-р хэсэг - Машин парк, бичиг баримт */

-- Өглөө бүр: 60 хоногт дуусах жолооны үнэмлэх, эрүүл мэндийн гэрчилгээ.
CREATE NONCLUSTERED INDEX IX_Drivers_LicenceExpiresOn
    ON dbo.Drivers (LicenceExpiresOn)
    INCLUDE (LicenceNumber, MedicalCertExpiresOn, HasHazmatEndorsement);
GO

CREATE NONCLUSTERED INDEX IX_MaintenanceRecords_Vehicle_PerformedOn
    ON dbo.MaintenanceRecords (VehicleId, PerformedOn DESC)
    INCLUDE (MaintenanceType, TotalCost, DownTimeHours);
GO

/* 4-р хэсэг - Нэхэмжлэх, төлбөр */

CREATE NONCLUSTERED INDEX IX_Invoices_Customer_IssueDate
    ON dbo.Invoices (CustomerId, IssueDate DESC)
    INCLUDE (Status, TotalAmount, DueDate);
GO

-- Авлагын насжилтад зөвхөн нээлттэй нэхэмжлэх хэрэгтэй тул filtered.
CREATE NONCLUSTERED INDEX IX_Invoices_Outstanding
    ON dbo.Invoices (DueDate)
    INCLUDE (CustomerId, InvoiceNumber, Status, TotalAmount)
    WHERE Status IN (N'Issued', N'PartiallyPaid', N'Overdue');
GO

CREATE NONCLUSTERED INDEX IX_Payments_PaidOn
    ON dbo.Payments (PaidOn)
    INCLUDE (InvoiceId, Amount);
GO

/* 5-р хэсэг - Дүрэм хэрэгжүүлдэг filtered unique индекс (UNIQUE constraint бүх мөрөнд үйлчилдэг) */

-- ДҮРЭМ: харилцагч бүрт нэг л үндсэн контакт.
CREATE UNIQUE NONCLUSTERED INDEX UX_CustomerContacts_OnePrimary
    ON dbo.CustomerContacts (CustomerId)
    WHERE IsPrimary = 1;
GO

-- ДҮРЭМ: рейс бүрт нэг л Primary жолооч, бусад нь CoDriver.
CREATE UNIQUE NONCLUSTERED INDEX UX_TripDrivers_OnePrimary
    ON dbo.TripDrivers (TripId)
    WHERE DriverRole = N'Primary';
GO

-- ДҮРЭМ: чиглэл + үйлчилгээ бүрт нэг л одоогийн үнэ (usp_CreateShipment үүнд найдна).
CREATE UNIQUE NONCLUSTERED INDEX UX_LaneRates_OneCurrentRate
    ON dbo.LaneRates (LaneId, ServiceLevelId)
    WHERE EffectiveTo IS NULL;
GO

DECLARE @IxCount INT =
(
    SELECT COUNT(*)
    FROM sys.indexes i
    JOIN sys.tables  t ON t.object_id = i.object_id
    WHERE i.type_desc = 'NONCLUSTERED'
      AND i.is_unique_constraint = 0
);
PRINT 'Nonclustered indexes created (excluding unique constraints): '
    + CAST(@IxCount AS VARCHAR(10));
GO
