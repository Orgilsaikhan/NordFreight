// Shapes returned by the FastAPI backend. Column names follow the SQL Server views.

export interface Page<T> {
  rows: T[]
  total: number
}

export interface MonthlyRevenue {
  MonthStart: string
  TotalRevenue: number
  ShipmentCount: number
  RevenueGrowthPct: number | null
}

export interface AtRiskShipment {
  ShipmentId: number
  TrackingNumber: string
  Status: string
  CustomerName: string
  OriginTerminal: string
  DestinationTerminal: string
  PromisedDeliveryDate: string
  DaysPastPromise: number
  RiskLevel: string
}

export interface CategoryRevenue {
  CategoryName: string
  ShipmentCount: number | null
  TotalRevenue: number
  RevenueSharePct: number | null
}

export interface Overview {
  kpis: {
    OpenShipments: number
    ExceptionShipments: number
    OnTimePct90d: number | null
    OutstandingBalance: number
    OverdueInvoices: number
  }
  revenue_trend: MonthlyRevenue[]
  at_risk: AtRiskShipment[]
  risk_counts: { RiskLevel: string; Shipments: number }[]
  categories: CategoryRevenue[]
}

export interface ShipmentRow {
  ShipmentId: number
  TrackingNumber: string
  Status: string
  CustomerId: number
  CustomerName: string
  OriginTerminal: string
  DestinationTerminal: string
  ServiceCode: string
  CategoryName: string
  PickupDate: string
  PromisedDeliveryDate: string
  ActualDeliveryDate: string | null
  TotalAmount: number
  DeliveryPerformance: string
  DaysLate: number | null
  BillingStatus: string
}

export interface ShipmentItem {
  LineNumber: number
  Description: string
  Quantity: number
  PackagingType: string
  UnitWeightKg: number
  UnitVolumeM3: number
  LineWeightKg: number
  LineVolumeM3: number
}

export interface StatusHistoryEntry {
  StatusHistoryId: number
  OldStatus: string | null
  NewStatus: string
  ChangedAt: string
  ChangedBy: string
  TerminalCode: string | null
  Notes: string | null
}

export interface ShipmentTrip {
  TripId: number
  TripNumber: string
  Status: string
  StopSequence: number
  LegType: string
  OriginTerminal: string
  DestinationTerminal: string
  ScheduledDeparture: string
  ActualDeparture: string | null
  ActualArrival: string | null
  PlateNumber: string
  Crew: string | null
}

export interface ShipmentDetail extends ShipmentRow {
  CustomerCode: string
  OriginCity: string
  DestinationCity: string
  DistanceKm: number
  ServiceName: string
  TotalWeightKg: number
  TotalVolumeM3: number
  FreightCharge: number
  SurchargeAmount: number
  TaxAmount: number
  InvoiceId: number | null
  InvoiceNumber: string | null
  OriginAddress: string
  DestinationAddress: string
  DeclaredValue: number
  IsInsured: boolean
  BookedAt: string
  items: ShipmentItem[]
  history: StatusHistoryEntry[]
  trips: ShipmentTrip[]
  next_statuses: string[]
}

export interface CustomerRow {
  CustomerId: number
  CustomerCode: string
  LegalName: string
  IsActive: boolean
  CreditLimit: number
  TotalShipments: number | null
  OpenShipments: number | null
  LifetimeRevenue: number
  OnTimePercentage: number | null
  OutstandingBalance: number | null
  LastShipmentDate: string | null
  DaysSinceLastShipment: number | null
}

export interface Contact {
  ContactId: number
  FullName: string
  JobTitle: string | null
  Email: string
  Phone: string | null
  IsPrimary: boolean
}

export interface CustomerInvoice {
  InvoiceId: number
  InvoiceNumber: string
  IssueDate: string
  DueDate: string
  Status: string
  TotalAmount: number
  BalanceDue: number
}

export interface CustomerDetail extends CustomerRow {
  PaymentTermsDays: number
  DeliveredShipments: number | null
  TradingName: string | null
  TaxNumber: string
  OnboardedOn: string
  BillingLine1: string
  BillingPostalCode: string
  BillingCity: string
  BillingCountry: string
  AvailableCredit: number
  contacts: Contact[]
  invoices: CustomerInvoice[]
}

export interface CustomerShipment {
  ShipmentId: number
  TrackingNumber: string
  Status: string
  OriginTerminal: string
  DestinationTerminal: string
  ServiceCode: string
  CategoryName: string
  PickupDate: string
  PromisedDeliveryDate: string
  ActualDeliveryDate: string | null
  TotalAmount: number
  DeliveryPerformance: string
  BillingStatus: string
  InvoiceNumber: string | null
}

export interface InvoiceRow {
  InvoiceId: number
  InvoiceNumber: string
  CustomerId: number
  CustomerCode: string
  CustomerName: string
  IssueDate: string
  DueDate: string
  Status: string
  Subtotal: number
  TaxAmount: number
  TotalAmount: number
  AmountPaid: number
  BalanceDue: number
  DaysOverdue: number | null
  AgeingBucket: string | null
}

export interface InvoiceList {
  rows: InvoiceRow[]
  ageing: { AgeingBucket: string; Invoices: number; BalanceDue: number }[]
}

export interface InvoiceLine {
  LineNumber: number
  ShipmentId: number
  TrackingNumber: string
  Description: string
  NetAmount: number
  TaxRate: number
  TaxAmount: number
  LineTotal: number
}

export interface Payment {
  PaymentId: number
  PaidOn: string
  Amount: number
  ReferenceNumber: string
  MethodName: string
}

export interface InvoiceDetail extends InvoiceRow {
  Notes: string | null
  lines: InvoiceLine[]
  payments: Payment[]
}

export interface Vehicle {
  VehicleId: number
  PlateNumber: string
  Vehicle: string
  ModelYear: number
  TypeCode: string
  VehicleType: string
  HomeTerminal: string
  Status: string
  OdometerKm: number
  TripCount: number
  KmDriven: number
  TotalMaintenanceCost: number
  MaintenanceCostPerKm: number | null
  LitresPer100Km: number | null
  LastServiceDate: string | null
}

export interface Driver {
  DriverId: number
  EmployeeCode: string
  DriverName: string
  HomeTerminal: string
  LicenceClass: string
  LicenceExpiresOn: string
  HasHazmatEndorsement: boolean
  IsCurrentlyEmployed: boolean | null
  TotalTrips: number | null
  TotalKmDriven: number
  TotalHoursOnDuty: number | null
  LastTripDeparture: string | null
  ComplianceStatus: string
}

export interface Lane {
  LaneId: number
  LaneName: string
  DistanceKm: number
  EstimatedDrivingHours: number
  IsActive: boolean
  ShipmentCount: number | null
  TotalRevenue: number
  TotalRevenuePerKm: number | null
  LateCount: number | null
  OnTimePercentage: number | null
  AvgActualTransitDays: number | null
}

export interface Lookups {
  customers: { CustomerId: number; CustomerCode: string; LegalName: string; IsActive: boolean }[]
  lanes: {
    LaneId: number
    OriginCode: string
    OriginCity: string
    DestinationCode: string
    DestinationCity: string
    DistanceKm: number
    IsActive: boolean
  }[]
  service_levels: { ServiceLevelId: number; ServiceCode: string; ServiceName: string; MaxTransitDays: number }[]
  cargo_categories: {
    CargoCategoryId: number
    CategoryCode: string
    CategoryName: string
    RequiresHazmat: boolean
    RequiresRefrigeration: boolean
    MaxDeclaredValue: number | null
  }[]
  addresses: { AddressId: number; Line1: string; PostalCode: string; CityName: string; IsoCode: string }[]
  terminals: { TerminalId: number; TerminalCode: string; TerminalName: string }[]
  payment_methods: { PaymentMethodId: number; MethodName: string }[]
}

export interface Quote {
  FreightCharge: number
  SurchargeAmount: number
  TaxAmount: number
  TotalAmount: number
}

export interface CreatedShipment extends Quote {
  ShipmentId: number
  TrackingNumber: string
  TotalWeightKg: number
}
