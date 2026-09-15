/*
  All 25 table definitions, grouped by subject area.
Нийт 25 хүснэгт үүссэн.

Энэ хэсэгт зөвхөн багана, дата төрөл, NULL байж болох эсэх, үндсэн түлхүүр, DEFAULT, тоо бодогддог багана, Гадаад төлхөөр, UNIQUE хязгаарлагчид л байна.
*/

USE NordFreightDB;
GO

-- PERSISTED тооцоолсон баганууд (computed columns) болон шүүлтүүртэй индексүүдэд (filtered indexes) шаардлагатай.
-- SSMS дээр энэ тохиргоог уг нь асаасан байдаг.  sqlcmd ашиглаж үүсгэсэн болохор өөрөө асаасан.


SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
  Эхний хэсэг - Газар
*/


-- Countries - тээвэрлэгчийн ажилладаг улсууд

CREATE TABLE dbo.Countries
(
    CountryId       INT             IDENTITY(1,1)   NOT NULL,
    IsoCode         CHAR(2)                         NOT NULL,
    CountryName     NVARCHAR(100)                   NOT NULL,
    CurrencyCode    CHAR(3)                         NOT NULL,
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Countries_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Countries PRIMARY KEY CLUSTERED (CountryId)
);
GO

-- Cities - хотууд (Addresses-аас салгаж нормчилсон)
CREATE TABLE dbo.Cities
(
    CityId          INT             IDENTITY(1,1)   NOT NULL,
    CountryId       INT                             NOT NULL,
    CityName        NVARCHAR(100)                   NOT NULL,
    Region          NVARCHAR(100)                   NOT NULL
        CONSTRAINT DF_Cities_Region DEFAULT (N'-'),
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Cities_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Cities PRIMARY KEY CLUSTERED (CityId)
);
GO

-- Addresses - харилцагч, терминал, ачааны нийтлэг хаягууд
CREATE TABLE dbo.Addresses
(
    AddressId       INT             IDENTITY(1,1)   NOT NULL,
    CityId          INT                             NOT NULL,
    Line1           NVARCHAR(150)                   NOT NULL,
    Line2           NVARCHAR(150)                       NULL,
    PostalCode      NVARCHAR(20)                    NOT NULL,
    Latitude        DECIMAL(9,6)                        NULL,
    Longitude       DECIMAL(9,6)                        NULL,
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Addresses_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Addresses_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Addresses PRIMARY KEY CLUSTERED (AddressId)
);
GO

/* Хоёр дахь хэсэг - Худалдаа / Харилцагчид */

-- Customers - ачаа захиалдаг компаниуд
CREATE TABLE dbo.Customers
(
    CustomerId          INT         IDENTITY(1,1)   NOT NULL,
    CustomerCode        NVARCHAR(20)                NOT NULL,   -- жишээ нь CUS-0007
    LegalName           NVARCHAR(200)               NOT NULL,
    TradingName         NVARCHAR(200)                   NULL,
    TaxNumber           NVARCHAR(30)                NOT NULL,
    BillingAddressId    INT                         NOT NULL,
    CreditLimit         DECIMAL(12,2)               NOT NULL
        CONSTRAINT DF_Customers_CreditLimit DEFAULT (0),
    PaymentTermsDays    SMALLINT                    NOT NULL
        CONSTRAINT DF_Customers_PaymentTermsDays DEFAULT (30),
    IsActive            BIT                         NOT NULL
        CONSTRAINT DF_Customers_IsActive DEFAULT (1),
    OnboardedOn         DATE                        NOT NULL,
    CreatedAt           DATETIME2(3)                NOT NULL
        CONSTRAINT DF_Customers_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt           DATETIME2(3)                NOT NULL
        CONSTRAINT DF_Customers_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    [RowVersion]        ROWVERSION                  NOT NULL,   -- optimistic concurrency-д хэрэглэх токен

    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerId)
);
GO

-- CustomerContacts - харилцагчийн холбоо барих хүмүүс
CREATE TABLE dbo.CustomerContacts
(
    ContactId       INT             IDENTITY(1,1)   NOT NULL,
    CustomerId      INT                             NOT NULL,
    FullName        NVARCHAR(150)                   NOT NULL,
    Email           NVARCHAR(256)                   NOT NULL,
    Phone           NVARCHAR(30)                        NULL,
    JobTitle        NVARCHAR(100)                       NULL,
    IsPrimary       BIT                             NOT NULL
        CONSTRAINT DF_CustomerContacts_IsPrimary DEFAULT (0),
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_CustomerContacts_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_CustomerContacts_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_CustomerContacts PRIMARY KEY CLUSTERED (ContactId)
);
GO

/* Гурав дахь хэсэг - Сүлжээ / Машин парк / Ажилтнууд */

-- Terminals - агуулах болон hub (төв терминал)-ууд
CREATE TABLE dbo.Terminals
(
    TerminalId      INT             IDENTITY(1,1)   NOT NULL,
    TerminalCode    NVARCHAR(10)                    NOT NULL,
    TerminalName    NVARCHAR(120)                   NOT NULL,
    AddressId       INT                             NOT NULL,
    IsHub           BIT                             NOT NULL    -- hub-ууд ачааг нэгтгэж болно
        CONSTRAINT DF_Terminals_IsHub DEFAULT (0),
    CapacityPallets INT                             NOT NULL,
    OpenedOn        DATE                            NOT NULL,
    IsActive        BIT                             NOT NULL
        CONSTRAINT DF_Terminals_IsActive DEFAULT (1),
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Terminals_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Terminals_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Terminals PRIMARY KEY CLUSTERED (TerminalId)
);
GO

-- Employees - бүх ажилтнууд; ManagerId шатлалыг "10 - Queries.sql"-ийн CTE уншина
CREATE TABLE dbo.Employees
(
    EmployeeId          INT         IDENTITY(1,1)   NOT NULL,
    EmployeeCode        NVARCHAR(20)                NOT NULL,
    FirstName           NVARCHAR(80)                NOT NULL,
    LastName            NVARCHAR(80)                NOT NULL,
    Email               NVARCHAR(256)               NOT NULL,
    Phone               NVARCHAR(30)                    NULL,
    JobTitle            NVARCHAR(40)                NOT NULL,
    HomeTerminalId      INT                         NOT NULL,
    ManagerId           INT                             NULL,   -- өөрийгөө заана
    HireDate            DATE                        NOT NULL,
    TerminationDate     DATE                            NULL,
    -- TerminationDate-ээс тооцдог тул зөрөхгүй
    IsCurrentlyEmployed AS CAST(CASE WHEN TerminationDate IS NULL THEN 1 ELSE 0 END AS BIT) PERSISTED,
    CreatedAt           DATETIME2(3)                NOT NULL
        CONSTRAINT DF_Employees_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt           DATETIME2(3)                NOT NULL
        CONSTRAINT DF_Employees_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Employees PRIMARY KEY CLUSTERED (EmployeeId)
);
GO

-- Drivers - Employees-ийн 1:1 өргөтгөл (DriverId нь PK ба FK)
CREATE TABLE dbo.Drivers
(
    DriverId                INT                     NOT NULL,   -- = Employees.EmployeeId
    LicenceNumber           NVARCHAR(30)            NOT NULL,
    LicenceClass            VARCHAR(2)              NOT NULL,   -- C, C1, CE, D
    LicenceIssuedOn         DATE                    NOT NULL,
    LicenceExpiresOn        DATE                    NOT NULL,
    MedicalCertExpiresOn    DATE                    NOT NULL,
    HasHazmatEndorsement    BIT                     NOT NULL
        CONSTRAINT DF_Drivers_HasHazmatEndorsement DEFAULT (0),
    MaxDailyDrivingHours    DECIMAL(4,2)            NOT NULL
        CONSTRAINT DF_Drivers_MaxDailyDrivingHours DEFAULT (9.00),
    CreatedAt               DATETIME2(3)            NOT NULL
        CONSTRAINT DF_Drivers_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt               DATETIME2(3)            NOT NULL
        CONSTRAINT DF_Drivers_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Drivers PRIMARY KEY CLUSTERED (DriverId)
);
GO

-- VehicleTypes - машины даацын ангилал
CREATE TABLE dbo.VehicleTypes
(
    VehicleTypeId        INT        IDENTITY(1,1)   NOT NULL,
    TypeCode             NVARCHAR(20)               NOT NULL,
    TypeName             NVARCHAR(80)               NOT NULL,
    MaxPayloadKg         DECIMAL(10,2)              NOT NULL,
    MaxVolumeM3          DECIMAL(10,2)              NOT NULL,
    AxleCount            TINYINT                    NOT NULL,
    IsRefrigerated       BIT                        NOT NULL
        CONSTRAINT DF_VehicleTypes_IsRefrigerated DEFAULT (0),
    RequiredLicenceClass VARCHAR(2)                 NOT NULL,
    CreatedAt            DATETIME2(3)               NOT NULL
        CONSTRAINT DF_VehicleTypes_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_VehicleTypes PRIMARY KEY CLUSTERED (VehicleTypeId)
);
GO

-- Vehicles - машин парк
CREATE TABLE dbo.Vehicles
(
    VehicleId       INT             IDENTITY(1,1)   NOT NULL,
    PlateNumber     NVARCHAR(15)                    NOT NULL,
    VIN             CHAR(17)                        NOT NULL,
    VehicleTypeId   INT                             NOT NULL,
    HomeTerminalId  INT                             NOT NULL,
    Make            NVARCHAR(50)                    NOT NULL,
    Model           NVARCHAR(50)                    NOT NULL,
    ModelYear       SMALLINT                        NOT NULL,
    AcquiredOn      DATE                            NOT NULL,
    OdometerKm      INT                             NOT NULL
        CONSTRAINT DF_Vehicles_OdometerKm DEFAULT (0),
    Status          NVARCHAR(20)                    NOT NULL
        CONSTRAINT DF_Vehicles_Status DEFAULT (N'Available'),
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Vehicles_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Vehicles_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Vehicles PRIMARY KEY CLUSTERED (VehicleId)
);
GO

-- MaintenanceRecords - машин бүрийн засварын түүх
CREATE TABLE dbo.MaintenanceRecords
(
    MaintenanceId   INT             IDENTITY(1,1)   NOT NULL,
    VehicleId       INT                             NOT NULL,
    MaintenanceType NVARCHAR(30)                    NOT NULL,
    PerformedOn     DATE                            NOT NULL,
    OdometerKm      INT                             NOT NULL,
    LabourCost      DECIMAL(10,2)                   NOT NULL
        CONSTRAINT DF_MaintenanceRecords_LabourCost DEFAULT (0),
    PartsCost       DECIMAL(10,2)                   NOT NULL
        CONSTRAINT DF_MaintenanceRecords_PartsCost DEFAULT (0),
    TotalCost       AS (LabourCost + PartsCost) PERSISTED,
    DownTimeHours   DECIMAL(6,2)                    NOT NULL
        CONSTRAINT DF_MaintenanceRecords_DownTimeHours DEFAULT (0),
    Notes           NVARCHAR(400)                       NULL,
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_MaintenanceRecords_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_MaintenanceRecords PRIMARY KEY CLUSTERED (MaintenanceId)
);
GO

/* Дөрөв дэх хэсэг - Үйлчилгээ, чиглэл, үнэ */

-- ServiceLevels - үйлчилгээний түвшин (Economy / Standard / Express)
CREATE TABLE dbo.ServiceLevels
(
    ServiceLevelId  INT             IDENTITY(1,1)   NOT NULL,
    ServiceCode     NVARCHAR(10)                    NOT NULL,
    ServiceName     NVARCHAR(60)                    NOT NULL,
    MaxTransitDays  TINYINT                         NOT NULL,
    PriceMultiplier DECIMAL(5,3)                    NOT NULL
        CONSTRAINT DF_ServiceLevels_PriceMultiplier DEFAULT (1.000),
    IsActive        BIT                             NOT NULL
        CONSTRAINT DF_ServiceLevels_IsActive DEFAULT (1),
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_ServiceLevels_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_ServiceLevels PRIMARY KEY CLUSTERED (ServiceLevelId)
);
GO

-- CargoCategories - ачааны ангилал, нэмэгдэл төлбөр ба шаардлагыг заана
CREATE TABLE dbo.CargoCategories
(
    CargoCategoryId       INT       IDENTITY(1,1)   NOT NULL,
    CategoryCode          NVARCHAR(15)              NOT NULL,
    CategoryName          NVARCHAR(80)              NOT NULL,
    RequiresHazmat        BIT                       NOT NULL
        CONSTRAINT DF_CargoCategories_RequiresHazmat DEFAULT (0),
    RequiresRefrigeration BIT                       NOT NULL
        CONSTRAINT DF_CargoCategories_RequiresRefrigeration DEFAULT (0),
    HandlingSurchargeRate DECIMAL(5,4)              NOT NULL    -- 0.0750 = +7.5%
        CONSTRAINT DF_CargoCategories_HandlingSurchargeRate DEFAULT (0),
    MaxDeclaredValue      DECIMAL(12,2)                 NULL,   -- NULL = дээд хязгааргүй
    CreatedAt             DATETIME2(3)              NOT NULL
        CONSTRAINT DF_CargoCategories_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_CargoCategories PRIMARY KEY CLUSTERED (CargoCategoryId)
);
GO

-- Lanes - терминалаас терминал руу явах нэг зүгийн чиглэл
CREATE TABLE dbo.Lanes
(
    LaneId                INT       IDENTITY(1,1)   NOT NULL,
    OriginTerminalId      INT                       NOT NULL,
    DestinationTerminalId INT                       NOT NULL,
    DistanceKm            DECIMAL(8,2)              NOT NULL,
    EstimatedDrivingHours DECIMAL(5,2)              NOT NULL,
    IsActive              BIT                       NOT NULL
        CONSTRAINT DF_Lanes_IsActive DEFAULT (1),
    CreatedAt             DATETIME2(3)              NOT NULL
        CONSTRAINT DF_Lanes_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt             DATETIME2(3)              NOT NULL
        CONSTRAINT DF_Lanes_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Lanes PRIMARY KEY CLUSTERED (LaneId)
);
GO

-- LaneRates - чиглэл + үйлчилгээний үнэ, хуучин үнийг дарахгүй хугацаагаар хадгална
CREATE TABLE dbo.LaneRates
(
    LaneRateId        INT           IDENTITY(1,1)   NOT NULL,
    LaneId            INT                           NOT NULL,
    ServiceLevelId    INT                           NOT NULL,
    RatePerKg         DECIMAL(9,4)                  NOT NULL,
    MinimumCharge     DECIMAL(10,2)                 NOT NULL,
    FuelSurchargeRate DECIMAL(5,4)                  NOT NULL
        CONSTRAINT DF_LaneRates_FuelSurchargeRate DEFAULT (0),
    EffectiveFrom     DATE                          NOT NULL,
    EffectiveTo       DATE                              NULL,   -- NULL = одоо хүчинтэй
    CreatedAt         DATETIME2(3)                  NOT NULL
        CONSTRAINT DF_LaneRates_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt         DATETIME2(3)                  NOT NULL
        CONSTRAINT DF_LaneRates_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_LaneRates PRIMARY KEY CLUSTERED (LaneRateId)
);
GO

/* Тав дахь хэсэг - Үйл ажиллагаа */

-- Shipments - гол транзакцын хүснэгт
CREATE TABLE dbo.Shipments
(
    ShipmentId           BIGINT     IDENTITY(1,1)   NOT NULL,
    TrackingNumber       NVARCHAR(20)               NOT NULL,
    CustomerId           INT                        NOT NULL,
    LaneId               INT                        NOT NULL,
    ServiceLevelId       INT                        NOT NULL,
    CargoCategoryId      INT                        NOT NULL,
    OriginAddressId      INT                        NOT NULL,
    DestinationAddressId INT                        NOT NULL,
    BookedAt             DATETIME2(3)               NOT NULL
        CONSTRAINT DF_Shipments_BookedAt DEFAULT (SYSUTCDATETIME()),
    PickupDate           DATE                       NOT NULL,
    PromisedDeliveryDate DATE                       NOT NULL,
    ActualDeliveryDate   DATE                           NULL,
    Status               NVARCHAR(20)               NOT NULL
        CONSTRAINT DF_Shipments_Status DEFAULT (N'Booked'),
    TotalWeightKg        DECIMAL(10,2)              NOT NULL,
    TotalVolumeM3        DECIMAL(10,3)              NOT NULL,
    DeclaredValue        DECIMAL(12,2)              NOT NULL
        CONSTRAINT DF_Shipments_DeclaredValue DEFAULT (0),
    FreightCharge        DECIMAL(12,2)              NOT NULL,
    SurchargeAmount      DECIMAL(12,2)              NOT NULL
        CONSTRAINT DF_Shipments_SurchargeAmount DEFAULT (0),
    TaxAmount            DECIMAL(12,2)              NOT NULL
        CONSTRAINT DF_Shipments_TaxAmount DEFAULT (0),
    TotalAmount          AS (FreightCharge + SurchargeAmount + TaxAmount) PERSISTED,
    IsInsured            BIT                        NOT NULL
        CONSTRAINT DF_Shipments_IsInsured DEFAULT (0),
    CreatedAt            DATETIME2(3)               NOT NULL
        CONSTRAINT DF_Shipments_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt            DATETIME2(3)               NOT NULL
        CONSTRAINT DF_Shipments_UpdatedAt DEFAULT (SYSUTCDATETIME()),
    [RowVersion]         ROWVERSION                 NOT NULL,

    CONSTRAINT PK_Shipments PRIMARY KEY CLUSTERED (ShipmentId)
);
GO

-- ShipmentItems - нэг ачааны палет, хайрцаг гэх мэт нэгжүүд
CREATE TABLE dbo.ShipmentItems
(
    ShipmentItemId  BIGINT          IDENTITY(1,1)   NOT NULL,
    ShipmentId      BIGINT                          NOT NULL,
    LineNumber      SMALLINT                        NOT NULL,
    Description     NVARCHAR(200)                   NOT NULL,
    Quantity        INT                             NOT NULL,
    UnitWeightKg    DECIMAL(9,3)                    NOT NULL,
    UnitVolumeM3    DECIMAL(9,4)                    NOT NULL,
    PackagingType   NVARCHAR(20)                    NOT NULL,
    LineWeightKg    AS (Quantity * UnitWeightKg) PERSISTED,
    LineVolumeM3    AS (Quantity * UnitVolumeM3) PERSISTED,
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_ShipmentItems_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_ShipmentItems PRIMARY KEY CLUSTERED (ShipmentItemId)
);
GO

-- ShipmentStatusHistory - төлөвийн өөрчлөлтийн түүх, триггер бичдэг
CREATE TABLE dbo.ShipmentStatusHistory
(
    StatusHistoryId BIGINT          IDENTITY(1,1)   NOT NULL,
    ShipmentId      BIGINT                          NOT NULL,
    OldStatus       NVARCHAR(20)                        NULL,   -- анх захиалах үед NULL
    NewStatus       NVARCHAR(20)                    NOT NULL,
    ChangedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_ShipmentStatusHistory_ChangedAt DEFAULT (SYSUTCDATETIME()),
    ChangedBy       NVARCHAR(128)                   NOT NULL
        CONSTRAINT DF_ShipmentStatusHistory_ChangedBy DEFAULT (SUSER_SNAME()),
    TerminalId      INT                                 NULL,
    Notes           NVARCHAR(400)                       NULL,

    CONSTRAINT PK_ShipmentStatusHistory PRIMARY KEY CLUSTERED (StatusHistoryId)
);
GO

-- Trips - хоёр терминалын хооронд явах рейс, олон ачаа зөөнө
CREATE TABLE dbo.Trips
(
    TripId                INT       IDENTITY(1,1)   NOT NULL,
    TripNumber            NVARCHAR(20)              NOT NULL,
    VehicleId             INT                       NOT NULL,
    OriginTerminalId      INT                       NOT NULL,
    DestinationTerminalId INT                       NOT NULL,
    ScheduledDeparture    DATETIME2(0)              NOT NULL,
    ScheduledArrival      DATETIME2(0)              NOT NULL,
    ActualDeparture       DATETIME2(0)                  NULL,
    ActualArrival         DATETIME2(0)                  NULL,
    StartOdometerKm       INT                           NULL,
    EndOdometerKm         INT                           NULL,
    FuelLitres            DECIMAL(9,2)                  NULL,
    Status                NVARCHAR(20)              NOT NULL
        CONSTRAINT DF_Trips_Status DEFAULT (N'Planned'),
    CreatedAt             DATETIME2(3)              NOT NULL
        CONSTRAINT DF_Trips_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt             DATETIME2(3)              NOT NULL
        CONSTRAINT DF_Trips_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Trips PRIMARY KEY CLUSTERED (TripId)
);
GO

-- TripDrivers - рейс <-> жолооч, урт замд хоёр жолоочтой явна
CREATE TABLE dbo.TripDrivers
(
    TripId      INT                                 NOT NULL,
    DriverId    INT                                 NOT NULL,
    DriverRole  NVARCHAR(15)                        NOT NULL
        CONSTRAINT DF_TripDrivers_DriverRole DEFAULT (N'Primary'),
    AssignedAt  DATETIME2(3)                        NOT NULL
        CONSTRAINT DF_TripDrivers_AssignedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_TripDrivers PRIMARY KEY CLUSTERED (TripId, DriverId)
);
GO

-- TripShipments - рейс <-> ачаа, hub-аар дамжих ачаа олон рейстэй
CREATE TABLE dbo.TripShipments
(
    TripId       INT                                NOT NULL,
    ShipmentId   BIGINT                             NOT NULL,
    StopSequence SMALLINT                           NOT NULL,
    LegType      NVARCHAR(15)                       NOT NULL,   -- Pickup / LineHaul / Delivery
    LoadedAt     DATETIME2(0)                           NULL,
    UnloadedAt   DATETIME2(0)                           NULL,

    CONSTRAINT PK_TripShipments PRIMARY KEY CLUSTERED (TripId, ShipmentId)
);
GO

/* Зургаа дахь хэсэг - Төлбөр тооцоо */

-- Invoices - нэг харилцагчийн хүргэгдсэн ачаануудын нэхэмжлэх
CREATE TABLE dbo.Invoices
(
    InvoiceId     INT               IDENTITY(1,1)   NOT NULL,
    InvoiceNumber NVARCHAR(20)                      NOT NULL,
    CustomerId    INT                               NOT NULL,
    IssueDate     DATE                              NOT NULL,
    DueDate       DATE                              NOT NULL,
    Status        NVARCHAR(15)                      NOT NULL
        CONSTRAINT DF_Invoices_Status DEFAULT (N'Draft'),
    Subtotal      DECIMAL(12,2)                     NOT NULL
        CONSTRAINT DF_Invoices_Subtotal DEFAULT (0),
    TaxAmount     DECIMAL(12,2)                     NOT NULL
        CONSTRAINT DF_Invoices_TaxAmount DEFAULT (0),
    TotalAmount   AS (Subtotal + TaxAmount) PERSISTED,
    Notes         NVARCHAR(400)                         NULL,
    CreatedAt     DATETIME2(3)                      NOT NULL
        CONSTRAINT DF_Invoices_CreatedAt DEFAULT (SYSUTCDATETIME()),
    UpdatedAt     DATETIME2(3)                      NOT NULL
        CONSTRAINT DF_Invoices_UpdatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Invoices PRIMARY KEY CLUSTERED (InvoiceId)
);
GO

-- InvoiceLines - ачаа бүрт яг нэг мөр
CREATE TABLE dbo.InvoiceLines
(
    InvoiceLineId INT               IDENTITY(1,1)   NOT NULL,
    InvoiceId     INT                               NOT NULL,
    ShipmentId    BIGINT                            NOT NULL,
    LineNumber    SMALLINT                          NOT NULL,
    Description   NVARCHAR(200)                     NOT NULL,
    NetAmount     DECIMAL(12,2)                     NOT NULL,
    TaxRate       DECIMAL(5,4)                      NOT NULL
        CONSTRAINT DF_InvoiceLines_TaxRate DEFAULT (0.2000),
    TaxAmount     AS CAST(ROUND(NetAmount * TaxRate, 2) AS DECIMAL(12,2)) PERSISTED,
    LineTotal     AS CAST(NetAmount + ROUND(NetAmount * TaxRate, 2) AS DECIMAL(12,2)) PERSISTED,
    CreatedAt     DATETIME2(3)                      NOT NULL
        CONSTRAINT DF_InvoiceLines_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_InvoiceLines PRIMARY KEY CLUSTERED (InvoiceLineId)
);
GO

-- PaymentMethods - төлбөрийн хэлбэрүүд (lookup)
CREATE TABLE dbo.PaymentMethods
(
    PaymentMethodId INT             IDENTITY(1,1)   NOT NULL,
    MethodCode      NVARCHAR(15)                    NOT NULL,
    MethodName      NVARCHAR(60)                    NOT NULL,
    IsActive        BIT                             NOT NULL
        CONSTRAINT DF_PaymentMethods_IsActive DEFAULT (1),
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_PaymentMethods_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_PaymentMethods PRIMARY KEY CLUSTERED (PaymentMethodId)
);
GO

-- Payments - хэсэгчлэн төлж болно, нэхэмжлэхэд 0..N төлбөр
CREATE TABLE dbo.Payments
(
    PaymentId       INT             IDENTITY(1,1)   NOT NULL,
    InvoiceId       INT                             NOT NULL,
    PaymentMethodId INT                             NOT NULL,
    PaidOn          DATE                            NOT NULL,
    Amount          DECIMAL(12,2)                   NOT NULL,
    ReferenceNumber NVARCHAR(50)                    NOT NULL,
    ReceivedBy      INT                                 NULL,   -- Employees.EmployeeId
    CreatedAt       DATETIME2(3)                    NOT NULL
        CONSTRAINT DF_Payments_CreatedAt DEFAULT (SYSUTCDATETIME()),

    CONSTRAINT PK_Payments PRIMARY KEY CLUSTERED (PaymentId)
);
GO

/* Долоо дахь хэсэг - Sequence-ууд */

-- MAX(...) + 1 зэрэг захиалга дээр давхцдаг тул дугаарыг sequence-ээс авна.
-- Жишээ дата ч ашигладаг тул "07 - Stored Procedures.sql"-д биш энд байна.

CREATE SEQUENCE dbo.seq_TrackingNumber AS INT START WITH 10000001 INCREMENT BY 1;
GO

CREATE SEQUENCE dbo.seq_TripNumber AS INT START WITH 30001 INCREMENT BY 1;
GO

-- Жил бүр 1-ээс эхэлнэ, он нь дугаарт ордог.
CREATE SEQUENCE dbo.seq_InvoiceNumber AS INT START WITH 1 INCREMENT BY 1;
GO

DECLARE @TableCount INT = (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo'));
PRINT 'Tables created: ' + CAST(@TableCount AS VARCHAR(10)) + ' (expected 25)';
GO
