/*
  NordFreight Logistics -- 09 - Жишээ дата
  Deterministic (RAND()/NEWID()-гүй, modulo) тул дахин ажиллуулахад тестүүд ижил гарна.
  Огноо бүгд өнөөдрөөс хамааралтай, сүүлийн 24 сарыг хамарна.
  Нэхэмжлэх, төлбөрийг usp_GenerateCustomerInvoice, usp_RecordPayment-ээр үүсгэнэ.
  Дүн: ~4,000 ачаа, ~10,000 бараа, ~2,350 рейс, ~250 нэхэмжлэх.
*/

USE NordFreightDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;
GO

-- Дата байвал зогсооно: дахин seed хийвэл давхардаад тестүүд эвдэрнэ.
IF EXISTS (SELECT 1 FROM dbo.Shipments)
BEGIN
    THROW 50090, 'The database already contains data. Re-run "01 - Database Creation.sql" first.', 1;
END
GO

/* 1-р хэсэг - Газар зүй */

SET IDENTITY_INSERT dbo.Countries ON;
INSERT INTO dbo.Countries (CountryId, IsoCode, CountryName, CurrencyCode) VALUES
    (1, 'EE', N'Estonia',   'EUR'),
    (2, 'LV', N'Latvia',    'EUR'),
    (3, 'LT', N'Lithuania', 'EUR'),
    (4, 'PL', N'Poland',    'PLN'),
    (5, 'FI', N'Finland',   'EUR'),
    (6, 'DE', N'Germany',   'EUR');
SET IDENTITY_INSERT dbo.Countries OFF;
GO

SET IDENTITY_INSERT dbo.Cities ON;
INSERT INTO dbo.Cities (CityId, CountryId, CityName, Region) VALUES
    ( 1, 1, N'Tallinn',     N'Harju'),
    ( 2, 1, N'Tartu',       N'Tartu'),
    ( 3, 1, N'Narva',       N'Ida-Viru'),
    ( 4, 2, N'Riga',        N'Riga'),
    ( 5, 2, N'Daugavpils',  N'Latgale'),
    ( 6, 2, N'Liepaja',     N'Kurzeme'),
    ( 7, 3, N'Vilnius',     N'Vilnius'),
    ( 8, 3, N'Kaunas',      N'Kaunas'),
    ( 9, 3, N'Klaipeda',    N'Klaipeda'),
    (10, 4, N'Warsaw',      N'Mazowieckie'),
    (11, 4, N'Gdansk',      N'Pomorskie'),
    (12, 4, N'Poznan',      N'Wielkopolskie'),
    (13, 5, N'Helsinki',    N'Uusimaa'),
    (14, 5, N'Turku',       N'Varsinais-Suomi'),
    (15, 6, N'Berlin',      N'Berlin'),
    (16, 6, N'Hamburg',     N'Hamburg');
SET IDENTITY_INSERT dbo.Cities OFF;
GO

SET IDENTITY_INSERT dbo.Addresses ON;

-- 1-7: терминалын хаяг (терминал бүрт тусдаа)
INSERT INTO dbo.Addresses (AddressId, CityId, Line1, Line2, PostalCode, Latitude, Longitude) VALUES
    ( 1,  1, N'Betooni tee 14',        N'Logistics Park A',  N'11415',  59.423600,  24.836100),
    ( 2,  4, N'Granita iela 32',       N'Terminal B',        N'LV-1057', 56.918700,  24.230500),
    ( 3,  7, N'Savanoriu pr. 247',     NULL,                 N'LT-02300', 54.652000, 25.211300),
    ( 4, 11, N'Kontenerowa 9',         N'Port Logistics',    N'80-601',  54.396500,  18.658400),
    ( 5, 10, N'Pologowa 24',           NULL,                 N'02-495',  52.196800,  20.897300),
    ( 6, 13, N'Rahtitie 6',            N'Vuosaari Harbour',  N'00980',   60.209100,  25.145600),
    ( 7, 15, N'Grossbeerenstrasse 71', N'Gewerbehof 3',      N'12107',   52.419800,  13.373900);

-- 8-19: харилцагчийн нэхэмжлэхийн хаяг
INSERT INTO dbo.Addresses (AddressId, CityId, Line1, Line2, PostalCode, Latitude, Longitude) VALUES
    ( 8,  1, N'Parnu maantee 158',     N'11th floor',        N'11317',  59.415800,  24.735600),
    ( 9,  2, N'Riia 181',              NULL,                 N'50411',  58.363700,  26.690300),
    (10,  4, N'Brivibas gatve 214',    N'Office 402',        N'LV-1039', 56.977100, 24.191200),
    (11,  6, N'Jurmalas iela 7',       NULL,                 N'LV-3401', 56.508400,  21.010300),
    (12,  7, N'Ukmerges g. 120',       N'Block C',           N'LT-08105', 54.720900, 25.263400),
    (13,  9, N'Taikos pr. 111',        NULL,                 N'LT-94231', 55.681800, 21.201600),
    (14, 10, N'Aleje Jerozolimskie 96', N'Suite 11',         N'00-807',  52.228900,  20.985700),
    (15, 11, N'Grunwaldzka 472',       NULL,                 N'80-309',  54.406200,  18.573400),
    (16, 12, N'Bulgarska 63',          N'Unit 8',            N'60-320',  52.400300,  16.850100),
    (17, 13, N'Mannerheimintie 113',   NULL,                 N'00280',   60.196500,  24.907800),
    (18, 15, N'Alexanderstrasse 3',    N'Haus 2',            N'10178',   52.520900,  13.414500),
    (19, 16, N'Billstrasse 186',       NULL,                 N'20539',   53.529700,  10.061800);

-- 20-49: ачаа авах, хүргэх цэгүүд
INSERT INTO dbo.Addresses (AddressId, CityId, Line1, Line2, PostalCode, Latitude, Longitude) VALUES
    (20,  1, N'Tartu maantee 83',      N'Loading bay 2',     N'10112',  59.432100,  24.771200),
    (21,  1, N'Peterburi tee 46',      NULL,                 N'11415',  59.428900,  24.847300),
    (22,  2, N'Ravila 51',             N'Gate 4',            N'50411',  58.377100,  26.714500),
    (23,  3, N'Tallinna maantee 19',   NULL,                 N'20304',  59.377800,  28.190100),
    (24,  4, N'Krasta iela 68',        N'Warehouse 12',      N'LV-1019', 56.928400, 24.140300),
    (25,  4, N'Ulmana gatve 119',      NULL,                 N'LV-1029', 56.920500,  24.020900),
    (26,  5, N'Jelgavas iela 4',       NULL,                 N'LV-5404', 55.874700,  26.517300),
    (27,  6, N'Brivibas iela 201',     N'Dock 3',            N'LV-3401', 56.523100,  21.023800),
    (28,  7, N'Laisves pr. 60',        NULL,                 N'LT-05120', 54.703400, 25.226700),
    (29,  7, N'Kirtimu g. 51',         N'Terminal 2',        N'LT-02244', 54.640900, 25.238100),
    (30,  8, N'Europos pr. 122',       NULL,                 N'LT-46351', 54.913400, 23.958200),
    (31,  9, N'Silutes pl. 95',        N'Port gate 7',       N'LT-91111', 55.667200, 21.176400),
    (32, 10, N'Polczynska 121',        NULL,                 N'01-304',  52.244600,  20.907800),
    (33, 10, N'Marywilska 44',         N'Hall D',            N'03-042',  52.312700,  21.011400),
    (34, 11, N'Elblaska 135',          NULL,                 N'80-718',  54.349800,  18.712300),
    (35, 11, N'Lotnicza 12',           N'Cargo centre',      N'80-297',  54.378200,  18.472100),
    (36, 12, N'Obornicka 330',         NULL,                 N'60-689',  52.469300,  16.902400),
    (37, 13, N'Satamakaari 24',        N'Terminal C',        N'00980',   60.212800,  25.184600),
    (38, 13, N'Konalantie 6',          NULL,                 N'00390',   60.239100,  24.858300),
    (39, 14, N'Pansiontie 47',         NULL,                 N'20240',   60.436700,  22.208900),
    (40, 15, N'Landsberger Allee 366', N'Gebaude 5',         N'12681',   52.535400,  13.542700),
    (41, 15, N'Nonnendammallee 104',   NULL,                 N'13629',   52.537800,  13.266900),
    (42, 16, N'Muggenburger Str. 18',  N'Halle 3',           N'20539',   53.532400,  10.054200),
    (43, 16, N'Waltershofer Damm 21',  NULL,                 N'21129',   53.523900,   9.892800),
    (44,  2, N'Turu 45',               NULL,                 N'51014',   58.371200,  26.736500),
    (45,  5, N'Smilsu iela 90',        N'Yard 2',            N'LV-5410', 55.881300, 26.540200),
    (46,  8, N'Islandijos g. 4',       NULL,                 N'LT-44241', 54.898700, 23.913600),
    (47, 12, N'Gorzyslawa 18',         NULL,                 N'61-321',  52.377400,  16.996200),
    (48, 14, N'Rieskalahdentie 80',    N'Unit 6',            N'20300',   60.442100,  22.256700),
    (49,  3, N'Rakvere 8',             NULL,                 N'20303',   59.369400,  28.174900);

SET IDENTITY_INSERT dbo.Addresses OFF;
GO

/* 2-р хэсэг - Сүлжээ: терминалууд */

SET IDENTITY_INSERT dbo.Terminals ON;
INSERT INTO dbo.Terminals (TerminalId, TerminalCode, TerminalName, AddressId, IsHub, CapacityPallets, OpenedOn) VALUES
    (1, N'TLL', N'Tallinn Central Terminal',   1, 1, 1800, '2011-04-01'),
    (2, N'RIX', N'Riga Distribution Hub',      2, 1, 2400, '2009-09-15'),
    (3, N'VNO', N'Vilnius Terminal',           3, 0, 1200, '2013-06-01'),
    (4, N'GDN', N'Gdansk Port Hub',            4, 1, 3200, '2015-03-20'),
    (5, N'WAW', N'Warsaw Terminal',            5, 0, 1600, '2016-11-07'),
    (6, N'HEL', N'Helsinki Terminal',          6, 0,  900, '2018-05-14'),
    (7, N'BER', N'Berlin Gateway',             7, 1, 2000, '2019-02-04');
SET IDENTITY_INSERT dbo.Terminals OFF;
GO

/* 3-р хэсэг - Ажилтнууд */

SET IDENTITY_INSERT dbo.Employees ON;

-- Pass 1: захирал. ManagerId өмнө орсон мөрийг заах ёстой тул дээрээс доош оруулна.
INSERT INTO dbo.Employees (EmployeeId, EmployeeCode, FirstName, LastName, Email, Phone, JobTitle, HomeTerminalId, ManagerId, HireDate) VALUES
    (1, N'EMP-0001', N'Kristjan', N'Saar', N'kristjan.saar@nordfreight.example', N'+372 5101 2001', N'Managing Director', 1, NULL, '2009-09-01');

-- Pass 2: удирдлага болон оффис
INSERT INTO dbo.Employees (EmployeeId, EmployeeCode, FirstName, LastName, Email, Phone, JobTitle, HomeTerminalId, ManagerId, HireDate) VALUES
    ( 2, N'EMP-0002', N'Marika',  N'Lepik',     N'marika.lepik@nordfreight.example',     N'+372 5101 2002', N'Operations Manager', 1, 1, '2010-02-15'),
    ( 3, N'EMP-0003', N'Toomas',  N'Kask',      N'toomas.kask@nordfreight.example',      N'+372 5101 2003', N'Terminal Manager',   1, 2, '2011-04-01'),
    ( 4, N'EMP-0004', N'Ilze',    N'Berzina',   N'ilze.berzina@nordfreight.example',     N'+371 2901 3004', N'Terminal Manager',   2, 2, '2010-06-10'),
    ( 5, N'EMP-0005', N'Darius',  N'Petrauskas',N'darius.petrauskas@nordfreight.example',N'+370 6801 4005', N'Terminal Manager',   3, 2, '2013-06-01'),
    ( 6, N'EMP-0006', N'Agnieszka',N'Kowalczyk',N'agnieszka.kowalczyk@nordfreight.example',N'+48 601 205 006', N'Terminal Manager', 4, 2, '2015-03-20'),
    ( 7, N'EMP-0007', N'Pawel',   N'Zielinski', N'pawel.zielinski@nordfreight.example',  N'+48 601 205 007', N'Terminal Manager',  5, 2, '2016-11-07'),
    ( 8, N'EMP-0008', N'Aino',    N'Virtanen',  N'aino.virtanen@nordfreight.example',    N'+358 40 550 008', N'Terminal Manager',  6, 2, '2018-05-14'),
    ( 9, N'EMP-0009', N'Lukas',   N'Brandt',    N'lukas.brandt@nordfreight.example',     N'+49 151 2300 09', N'Terminal Manager',  7, 2, '2019-02-04'),
    (10, N'EMP-0010', N'Kadri',   N'Ilves',     N'kadri.ilves@nordfreight.example',      N'+372 5101 2010', N'Dispatcher',         1, 3, '2017-08-21'),
    (11, N'EMP-0011', N'Janis',   N'Ozols',     N'janis.ozols@nordfreight.example',      N'+371 2901 3011', N'Dispatcher',         2, 4, '2016-03-14'),
    (12, N'EMP-0012', N'Marta',   N'Nowak',     N'marta.nowak@nordfreight.example',      N'+48 601 205 012', N'Dispatcher',        4, 6, '2019-09-02'),
    (13, N'EMP-0013', N'Piret',   N'Tamm',      N'piret.tamm@nordfreight.example',       N'+372 5101 2013', N'Billing Clerk',      1, 2, '2014-01-13'),
    (14, N'EMP-0014', N'Liga',    N'Kalnina',   N'liga.kalnina@nordfreight.example',     N'+371 2901 3014', N'Billing Clerk',      2, 2, '2018-10-01'),
    (15, N'EMP-0015', N'Rein',    N'Mets',      N'rein.mets@nordfreight.example',        N'+372 5101 2015', N'Fleet Technician',   1, 3, '2012-05-07'),
    (16, N'EMP-0016', N'Tomasz',  N'Wisniewski',N'tomasz.wisniewski@nordfreight.example',N'+48 601 205 016', N'Fleet Technician',  4, 6, '2017-02-20');

-- Pass 3: жолооч нар (EmployeeId 17-32)
INSERT INTO dbo.Employees (EmployeeId, EmployeeCode, FirstName, LastName, Email, Phone, JobTitle, HomeTerminalId, ManagerId, HireDate, TerminationDate) VALUES
    (17, N'EMP-0017', N'Andres',  N'Kuusk',      N'andres.kuusk@nordfreight.example',      N'+372 5101 2017', N'Driver', 1, 3, '2012-03-05', NULL),
    (18, N'EMP-0018', N'Priit',   N'Raudsepp',   N'priit.raudsepp@nordfreight.example',    N'+372 5101 2018', N'Driver', 1, 3, '2014-07-18', NULL),
    (19, N'EMP-0019', N'Margus',  N'Sepp',       N'margus.sepp@nordfreight.example',       N'+372 5101 2019', N'Driver', 1, 3, '2016-01-11', NULL),
    (20, N'EMP-0020', N'Valters', N'Krumins',    N'valters.krumins@nordfreight.example',   N'+371 2901 3020', N'Driver', 2, 4, '2011-09-26', NULL),
    (21, N'EMP-0021', N'Edgars',  N'Liepins',    N'edgars.liepins@nordfreight.example',    N'+371 2901 3021', N'Driver', 2, 4, '2015-04-02', NULL),
    (22, N'EMP-0022', N'Normunds',N'Zarins',     N'normunds.zarins@nordfreight.example',   N'+371 2901 3022', N'Driver', 2, 4, '2018-06-19', NULL),
    (23, N'EMP-0023', N'Tomas',   N'Jankauskas', N'tomas.jankauskas@nordfreight.example',  N'+370 6801 4023', N'Driver', 3, 5, '2013-10-08', NULL),
    (24, N'EMP-0024', N'Mindaugas',N'Butkus',    N'mindaugas.butkus@nordfreight.example',  N'+370 6801 4024', N'Driver', 3, 5, '2017-05-22', NULL),
    (25, N'EMP-0025', N'Marek',   N'Lewandowski',N'marek.lewandowski@nordfreight.example', N'+48 601 205 025', N'Driver', 4, 6, '2015-08-31', NULL),
    (26, N'EMP-0026', N'Piotr',   N'Szymanski',  N'piotr.szymanski@nordfreight.example',   N'+48 601 205 026', N'Driver', 4, 6, '2016-12-05', NULL),
    (27, N'EMP-0027', N'Grzegorz',N'Dabrowski',  N'grzegorz.dabrowski@nordfreight.example',N'+48 601 205 027', N'Driver', 4, 6, '2019-03-11', NULL),
    (28, N'EMP-0028', N'Krzysztof',N'Mazur',     N'krzysztof.mazur@nordfreight.example',   N'+48 601 205 028', N'Driver', 5, 7, '2017-11-13', NULL),
    (29, N'EMP-0029', N'Juha',    N'Nieminen',   N'juha.nieminen@nordfreight.example',     N'+358 40 550 029', N'Driver', 6, 8, '2018-07-02', NULL),
    (30, N'EMP-0030', N'Mikko',   N'Heikkinen',  N'mikko.heikkinen@nordfreight.example',   N'+358 40 550 030', N'Driver', 6, 8, '2020-02-17', NULL),
    (31, N'EMP-0031', N'Stefan',  N'Wagner',     N'stefan.wagner@nordfreight.example',     N'+49 151 2300 31', N'Driver', 7, 9, '2019-04-15', NULL),
    -- Ажлаас гарсан: "идэвхтэй ажилтан" шүүлтүүрийг шалгахад
    (32, N'EMP-0032', N'Hendrik', N'Vares',      N'hendrik.vares@nordfreight.example',     N'+372 5101 2032', N'Driver', 1, 3, '2013-02-04',
         DATEADD(MONTH, -8, CAST(SYSUTCDATETIME() AS DATE)));

SET IDENTITY_INSERT dbo.Employees OFF;
GO

-- Жолоочийн профайл (Employees-ийн 1:1 өргөтгөл).
-- Compliance query-д: 30-р жолоочийн үнэмлэх 60 хоногт дуусна,
-- 32-р жолоочийнх хугацаа дууссан, өөрөө ажлаас гарсан.
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

INSERT INTO dbo.Drivers (DriverId, LicenceNumber, LicenceClass, LicenceIssuedOn, LicenceExpiresOn, MedicalCertExpiresOn, HasHazmatEndorsement, MaxDailyDrivingHours) VALUES
    (17, N'EE-DL-448120', 'CE', '2019-03-01', DATEADD(MONTH,  26, @Today), DATEADD(MONTH, 14, @Today), 1, 9.00),
    (18, N'EE-DL-451077', 'CE', '2020-07-12', DATEADD(MONTH,  31, @Today), DATEADD(MONTH, 20, @Today), 0, 9.00),
    (19, N'EE-DL-460913', 'C',  '2021-01-20', DATEADD(MONTH,  18, @Today), DATEADD(MONTH,  9, @Today), 0, 9.00),
    (20, N'LV-DL-227341', 'CE', '2018-11-05', DATEADD(MONTH,  22, @Today), DATEADD(MONTH, 16, @Today), 1, 10.00),
    (21, N'LV-DL-231908', 'CE', '2020-02-18', DATEADD(MONTH,  29, @Today), DATEADD(MONTH, 11, @Today), 0, 9.00),
    (22, N'LV-DL-240556', 'C',  '2021-06-30', DATEADD(MONTH,  35, @Today), DATEADD(MONTH, 23, @Today), 0, 9.00),
    (23, N'LT-DL-318772', 'CE', '2019-08-14', DATEADD(MONTH,  20, @Today), DATEADD(MONTH, 13, @Today), 1, 9.00),
    (24, N'LT-DL-325410', 'CE', '2020-10-09', DATEADD(MONTH,  27, @Today), DATEADD(MONTH, 18, @Today), 0, 9.00),
    (25, N'PL-DL-556201', 'CE', '2018-05-23', DATEADD(MONTH,  24, @Today), DATEADD(MONTH, 15, @Today), 1, 10.00),
    (26, N'PL-DL-561889', 'CE', '2019-12-02', DATEADD(MONTH,  33, @Today), DATEADD(MONTH, 21, @Today), 0, 9.00),
    (27, N'PL-DL-570334', 'C',  '2021-03-17', DATEADD(MONTH,  16, @Today), DATEADD(MONTH,  8, @Today), 0, 9.00),
    (28, N'PL-DL-574902', 'CE', '2020-09-28', DATEADD(MONTH,  28, @Today), DATEADD(MONTH, 17, @Today), 1, 9.00),
    (29, N'FI-DL-880145', 'CE', '2019-06-11', DATEADD(MONTH,  21, @Today), DATEADD(MONTH, 12, @Today), 0, 9.00),
    (30, N'FI-DL-884763', 'C1', '2021-08-04', DATEADD(DAY,    41, @Today), DATEADD(MONTH,  6, @Today), 0, 8.00),
    (31, N'DE-DL-119538', 'CE', '2020-04-27', DATEADD(MONTH,  30, @Today), DATEADD(MONTH, 19, @Today), 1, 10.00),
    (32, N'EE-DL-439006', 'CE', '2016-02-10', DATEADD(MONTH,  -7, @Today), DATEADD(MONTH, -9, @Today), 0, 9.00);
GO

-- 48 жолооч нэмж үүсгэнэ: ачаалалтай өдөр ~50 ээлж гардаг тул давхар хуваарилахгүй.
-- Нэрс улс бүрийн жагсаалтаас, менежер нь терминалын менежер (EmployeeId 3-9).
-- Тал нь ADR зөвшөөрөлтэй, 9-р хэсэгт аюултай ачааны рейсэд хэрэгтэй.
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

DECLARE @FirstNames TABLE (CountryCode CHAR(2) NOT NULL, Slot INT NOT NULL, FirstName NVARCHAR(80) NOT NULL,
                           PRIMARY KEY (CountryCode, Slot));
INSERT INTO @FirstNames (CountryCode, Slot, FirstName) VALUES
    ('EE', 0, N'Rasmus'), ('EE', 1, N'Siim'),    ('EE', 2, N'Kristo'),  ('EE', 3, N'Tanel'),
    ('EE', 4, N'Urmas'),  ('EE', 5, N'Jaan'),    ('EE', 6, N'Oliver'),  ('EE', 7, N'Karl'),
    ('LV', 0, N'Andris'), ('LV', 1, N'Maris'),   ('LV', 2, N'Kaspars'), ('LV', 3, N'Raimonds'),
    ('LV', 4, N'Aigars'), ('LV', 5, N'Guntis'),  ('LV', 6, N'Ivars'),   ('LV', 7, N'Artis'),
    ('LT', 0, N'Jonas'),  ('LT', 1, N'Mantas'),  ('LT', 2, N'Paulius'), ('LT', 3, N'Rokas'),
    ('LT', 4, N'Andrius'),('LT', 5, N'Tadas'),   ('LT', 6, N'Lukas'),   ('LT', 7, N'Vilius'),
    ('PL', 0, N'Jakub'),  ('PL', 1, N'Kamil'),   ('PL', 2, N'Adam'),    ('PL', 3, N'Marcin'),
    ('PL', 4, N'Lukasz'), ('PL', 5, N'Rafal'),   ('PL', 6, N'Michal'),  ('PL', 7, N'Pawel'),
    ('FI', 0, N'Janne'),  ('FI', 1, N'Teemu'),   ('FI', 2, N'Antti'),   ('FI', 3, N'Ville'),
    ('FI', 4, N'Sami'),   ('FI', 5, N'Jari'),    ('FI', 6, N'Pekka'),   ('FI', 7, N'Timo'),
    ('DE', 0, N'Felix'),  ('DE', 1, N'Tobias'),  ('DE', 2, N'Jan'),     ('DE', 3, N'Matthias'),
    ('DE', 4, N'Sven'),   ('DE', 5, N'Dennis'),  ('DE', 6, N'Marco'),   ('DE', 7, N'Florian');

DECLARE @LastNames TABLE (CountryCode CHAR(2) NOT NULL, Slot INT NOT NULL, LastName NVARCHAR(80) NOT NULL,
                          PRIMARY KEY (CountryCode, Slot));
INSERT INTO @LastNames (CountryCode, Slot, LastName) VALUES
    ('EE', 0, N'Tamm'),       ('EE', 1, N'Magi'),         ('EE', 2, N'Kukk'),         ('EE', 3, N'Rebane'),
    ('EE', 4, N'Parn'),       ('EE', 5, N'Lill'),         ('EE', 6, N'Oja'),          ('EE', 7, N'Kivi'),
    ('LV', 0, N'Kalnins'),    ('LV', 1, N'Liepa'),        ('LV', 2, N'Jansons'),      ('LV', 3, N'Vitols'),
    ('LV', 4, N'Krastins'),   ('LV', 5, N'Petersons'),    ('LV', 6, N'Ozolins'),      ('LV', 7, N'Balodis'),
    ('LT', 0, N'Kazlauskas'), ('LT', 1, N'Stankevicius'), ('LT', 2, N'Vasiliauskas'), ('LT', 3, N'Zukauskas'),
    ('LT', 4, N'Navickas'),   ('LT', 5, N'Rimkus'),       ('LT', 6, N'Butkevicius'),  ('LT', 7, N'Sakalauskas'),
    ('PL', 0, N'Wojcik'),     ('PL', 1, N'Wozniak'),      ('PL', 2, N'Kozlowski'),    ('PL', 3, N'Jankowski'),
    ('PL', 4, N'Mazurek'),    ('PL', 5, N'Pawlak'),       ('PL', 6, N'Krawczyk'),     ('PL', 7, N'Grabowski'),
    ('FI', 0, N'Korhonen'),   ('FI', 1, N'Makinen'),      ('FI', 2, N'Hamalainen'),   ('FI', 3, N'Laine'),
    ('FI', 4, N'Koskinen'),   ('FI', 5, N'Lehtonen'),     ('FI', 6, N'Salminen'),     ('FI', 7, N'Heinonen'),
    ('DE', 0, N'Schmidt'),    ('DE', 1, N'Fischer'),      ('DE', 2, N'Weber'),        ('DE', 3, N'Becker'),
    ('DE', 4, N'Koch'),       ('DE', 5, N'Richter'),      ('DE', 6, N'Wolf'),         ('DE', 7, N'Neumann');

SET IDENTITY_INSERT dbo.Employees ON;

INSERT INTO dbo.Employees
    (EmployeeId, EmployeeCode, FirstName, LastName, Email, Phone, JobTitle, HomeTerminalId, ManagerId, HireDate)
SELECT
    32 + g.n,
    N'EMP-' + RIGHT(N'0000' + CAST(32 + g.n AS NVARCHAR(10)), 4),
    fn.FirstName,
    ln.LastName,
    -- ижил нэртэй жолооч давхцахгүйн тулд дугаар нэмнэ
    LOWER(fn.FirstName + N'.' + ln.LastName) + N'.' + CAST(32 + g.n AS NVARCHAR(10)) + N'@nordfreight.example',
    cc.PhonePrefix + CAST(4000000 + (g.n * 7919) % 5000000 AS NVARCHAR(10)),
    N'Driver',
    g.HomeTerminalId,
    g.HomeTerminalId + 2,
    DATEFROMPARTS(2012 + g.n % 10, 1 + g.n % 12, 1 + g.n % 28)
FROM
(
    SELECT t.n,
           -- ачаалалтай терминалуудад (RIX, GDN, TLL) илүү олон жолооч
           CASE t.n % 11
               WHEN 0 THEN 2 WHEN 1 THEN 2 WHEN 2 THEN 2
               WHEN 3 THEN 4 WHEN 4 THEN 4
               WHEN 5 THEN 1 WHEN 6 THEN 1
               WHEN 7 THEN 3 WHEN 8 THEN 5 WHEN 9 THEN 7
               ELSE 6
           END AS HomeTerminalId
    FROM (SELECT TOP (48) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
          FROM sys.all_objects) AS t
) AS g
INNER JOIN
(
    VALUES (1, 'EE', N'+372 5'), (2, 'LV', N'+371 2'), (3, 'LT', N'+370 6'), (4, 'PL', N'+48 6'),
           (5, 'PL', N'+48 6'),  (6, 'FI', N'+358 4'), (7, 'DE', N'+49 15')
) AS cc (TerminalId, CountryCode, PhonePrefix)
        ON cc.TerminalId = g.HomeTerminalId
INNER JOIN @FirstNames AS fn ON fn.CountryCode = cc.CountryCode AND fn.Slot = g.n % 8
INNER JOIN @LastNames  AS ln ON ln.CountryCode = cc.CountryCode AND ln.Slot = (g.n * 3 + 1) % 8;

SET IDENTITY_INSERT dbo.Employees OFF;

INSERT INTO dbo.Drivers
    (DriverId, LicenceNumber, LicenceClass, LicenceIssuedOn, LicenceExpiresOn,
     MedicalCertExpiresOn, HasHazmatEndorsement, MaxDailyDrivingHours)
SELECT
    e.EmployeeId,
    cc.CountryCode + N'-DL-' + CAST(700000 + e.EmployeeId AS NVARCHAR(10)),
    'CE',
    DATEADD(YEAR, -2, e.HireDate),
    DATEADD(MONTH, 14 + (e.EmployeeId * 7) % 30, @Today),
    DATEADD(MONTH,  6 + (e.EmployeeId * 5) % 18, @Today),
    CASE WHEN e.EmployeeId % 2 = 0 THEN 1 ELSE 0 END,
    CASE WHEN e.EmployeeId % 4 = 0 THEN 10.00 ELSE 9.00 END
FROM dbo.Employees AS e
INNER JOIN
(
    VALUES (1, 'EE'), (2, 'LV'), (3, 'LT'), (4, 'PL'), (5, 'PL'), (6, 'FI'), (7, 'DE')
) AS cc (TerminalId, CountryCode)
        ON cc.TerminalId = e.HomeTerminalId
WHERE e.EmployeeId > 32;

PRINT 'Generated drivers: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

/* 4-р хэсэг - Машин парк */

SET IDENTITY_INSERT dbo.VehicleTypes ON;
INSERT INTO dbo.VehicleTypes (VehicleTypeId, TypeCode, TypeName, MaxPayloadKg, MaxVolumeM3, AxleCount, IsRefrigerated, RequiredLicenceClass) VALUES
    (1, N'VAN35',  N'3.5t Panel Van',            1200.00, 12.00, 2, 0, 'C1'),
    (2, N'RIG75',  N'7.5t Rigid Truck',          3500.00, 35.00, 2, 0, 'C'),
    (3, N'RIG12',  N'12t Rigid Truck',           6500.00, 48.00, 2, 0, 'C'),
    (4, N'RIG18',  N'18t Rigid Truck',           9500.00, 60.00, 3, 0, 'C'),
    (5, N'ARTIC',  N'Articulated Curtainsider', 24000.00, 90.00, 5, 0, 'CE'),
    (6, N'REEFER', N'Refrigerated Semi-Trailer',22000.00, 82.00, 5, 1, 'CE');
SET IDENTITY_INSERT dbo.VehicleTypes OFF;
GO

SET IDENTITY_INSERT dbo.Vehicles ON;
INSERT INTO dbo.Vehicles (VehicleId, PlateNumber, VIN, VehicleTypeId, HomeTerminalId, Make, Model, ModelYear, AcquiredOn, OdometerKm, Status) VALUES
    ( 1, N'123 ABC', 'WMA06XZZ4NM734821', 5, 1, N'MAN',      N'TGX 18.510',   2022, '2022-03-14', 412870, N'Available'),
    ( 2, N'456 BCD', 'WMA06XZZ1PM739044', 5, 1, N'MAN',      N'TGX 18.470',   2023, '2023-01-09', 268430, N'Available'),
    ( 3, N'789 CDE', 'YS2R4X20005398271', 6, 1, N'Scania',   N'R450 Reefer',  2021, '2021-06-22', 531265, N'Available'),
    ( 4, N'LV1234',  'VLUR4X20009471553', 5, 2, N'Volvo',    N'FH 460',       2022, '2022-08-30', 389114, N'Available'),
    ( 5, N'LV5678',  'VLUR4X20004418827', 6, 2, N'Volvo',    N'FH 500 Reefer',2023, '2023-04-11', 197658, N'Available'),
    ( 6, N'LV9012',  'WDB9634031L826194', 4, 2, N'Mercedes', N'Actros 1845',  2020, '2020-11-03', 623409, N'Available'),
    ( 7, N'LTA345',  'YS2R4X20007712064', 5, 3, N'Scania',   N'S500',         2021, '2021-09-17', 458720, N'Available'),
    ( 8, N'LTB678',  'WDB9634031L719238', 3, 3, N'Mercedes', N'Atego 1224',   2019, '2019-05-28', 512883, N'Available'),
    ( 9, N'GD01234', 'WMA06XZZ8LM612977', 5, 4, N'MAN',      N'TGX 26.510',   2021, '2021-02-19', 497331, N'Available'),
    (10, N'GD05678', 'VLUR4X20003356140', 6, 4, N'Volvo',    N'FH 460 Reefer',2022, '2022-07-05', 312047, N'Available'),
    (11, N'GD09012', 'YS2R4X20002284916', 5, 4, N'Scania',   N'R500',         2023, '2023-03-27', 184592, N'Available'),
    (12, N'WA03456', 'WDB9634031L904725', 4, 5, N'Mercedes', N'Actros 1848',  2020, '2020-06-15', 588216, N'Available'),
    (13, N'WA07890', 'WMA06XZZ3KM548310', 3, 5, N'MAN',      N'TGM 15.250',   2018, '2018-10-22', 671904, N'InMaintenance'),
    (14, N'ABC-123', 'YS2R4X20001197438', 5, 6, N'Scania',   N'R450',         2022, '2022-05-06', 274613, N'Available'),
    (15, N'DEF-456', 'VLUR4X20008823075', 2, 6, N'Volvo',    N'FL 280',       2021, '2021-11-30', 208745, N'Available'),
    (16, N'B XY 421','WDB9634031L339582', 5, 7, N'Mercedes', N'Actros 1851',  2023, '2023-08-18', 141338, N'Available');
SET IDENTITY_INSERT dbo.Vehicles OFF;
GO

-- 20 ARTIC, 18 REEFER нэмнэ: ачаалалтай өдөр ~25 + ~18 рейс зэрэг явдаг тул машин давхардахгүй.
-- VIN жинхэнэ prefix-тэй тул CK_Vehicles_VIN-ийг давна.
-- OdometerKm 0-ээс эхэлж, 9-р хэсэгт рейсийн түүхээс бодогдоно.
INSERT INTO dbo.Vehicles
    (PlateNumber, VIN, VehicleTypeId, HomeTerminalId, Make, Model, ModelYear, AcquiredOn, OdometerKm, Status)
SELECT
    CASE g.HomeTerminalId
        WHEN 1 THEN CONCAT(200 + g.n, N' NF', NCHAR(65 + g.n % 26))        -- Эстони     201 NFB
        WHEN 2 THEN CONCAT(N'NF', 3000 + g.n)                               -- Латви      NF3001
        WHEN 3 THEN CONCAT(N'NF', NCHAR(65 + g.n % 26), N' ', 400 + g.n)    -- Литва      NFB 401
        WHEN 4 THEN CONCAT(N'GD ', 50000 + g.n)                             -- Польш      GD 50001
        WHEN 5 THEN CONCAT(N'WA ', 60000 + g.n)                             -- Польш      WA 60001
        WHEN 6 THEN CONCAT(N'NF', NCHAR(65 + g.n % 26), N'-', 500 + g.n)    -- Финланд    NFB-501
        ELSE        CONCAT(N'B NF ', 600 + g.n)                             -- Герман     B NF 601
    END,
    -- VIN: prefix (9) + оны код (1) + үйлдвэр (1) + серийн дугаар (6) = 17
    CONCAT(mk.VinPrefix, SUBSTRING('KLMNP', 1 + g.n % 5, 1), 'L', 700000 + g.n),
    g.VehicleTypeId,
    g.HomeTerminalId,
    mk.Make,
    CASE WHEN g.VehicleTypeId = 5 THEN mk.ArticModel ELSE mk.ReeferModel END,
    2019 + g.n % 5,
    DATEFROMPARTS(2019 + g.n % 5, 1 + g.n % 12, 1 + g.n % 27),
    0,
    N'Available'
FROM
(
    SELECT
        t.n,
        CASE WHEN t.n <= 20 THEN 5 ELSE 6 END AS VehicleTypeId,     -- эхлээд 20 ARTIC, дараа нь 18 REEFER
        CASE t.n % 10
            WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 4 WHEN 3 THEN 7 WHEN 4 THEN 2
            WHEN 5 THEN 4 WHEN 6 THEN 3 WHEN 7 THEN 5 WHEN 8 THEN 1 ELSE 6
        END AS HomeTerminalId
    FROM (SELECT TOP (38) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
          FROM sys.all_objects) AS t
) AS g
INNER JOIN
(
    VALUES (0, N'MAN',      N'TGX 18.510',  N'TGX 18.470 Reefer',  'WMA06XZZ4'),
           (1, N'Scania',   N'R450',        N'R500 Reefer',        'YS2R4X200'),
           (2, N'Volvo',    N'FH 460',      N'FH 500 Reefer',      'YV2RTY0A1'),
           (3, N'Mercedes', N'Actros 1851', N'Actros 1848 Reefer', 'WDB963403')
) AS mk (Slot, Make, ArticModel, ReeferModel, VinPrefix)
    ON mk.Slot = g.n % 4;

PRINT 'Generated vehicles: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

/* 5-р хэсэг - Үйлчилгээний каталог */

SET IDENTITY_INSERT dbo.ServiceLevels ON;
INSERT INTO dbo.ServiceLevels (ServiceLevelId, ServiceCode, ServiceName, MaxTransitDays, PriceMultiplier, IsActive) VALUES
    (1, N'ECON', N'Economy Groupage',   7, 0.850, 1),
    (2, N'STD',  N'Standard Freight',   4, 1.000, 1),
    (3, N'EXP',  N'Express',            2, 1.450, 1),
    (4, N'NEXT', N'Next Day Priority',  1, 2.200, 1);
SET IDENTITY_INSERT dbo.ServiceLevels OFF;
GO

SET IDENTITY_INSERT dbo.CargoCategories ON;
INSERT INTO dbo.CargoCategories (CargoCategoryId, CategoryCode, CategoryName, RequiresHazmat, RequiresRefrigeration, HandlingSurchargeRate, MaxDeclaredValue) VALUES
    (1, N'GEN',   N'General Freight',       0, 0, 0.0000, NULL),
    (2, N'PAL',   N'Palletised Goods',      0, 0, 0.0200, NULL),
    (3, N'FRAG',  N'Fragile Goods',         0, 0, 0.0850,  250000.00),
    (4, N'CHILL', N'Chilled Foodstuffs',    0, 1, 0.1200,  150000.00),
    (5, N'FROZ',  N'Frozen Goods',          0, 1, 0.1500,  150000.00),
    (6, N'HAZ',   N'Dangerous Goods (ADR)', 1, 0, 0.2200,  500000.00),
    (7, N'AUTO',  N'Automotive Parts',      0, 0, 0.0400, NULL),
    (8, N'ELEC',  N'Electronics',           0, 0, 0.0950,  750000.00);
SET IDENTITY_INSERT dbo.CargoCategories OFF;
GO

SET IDENTITY_INSERT dbo.PaymentMethods ON;
INSERT INTO dbo.PaymentMethods (PaymentMethodId, MethodCode, MethodName, IsActive) VALUES
    (1, N'BANKXFER', N'Bank Transfer',   1),
    (2, N'DIRDEB',   N'Direct Debit',    1),
    (3, N'CARD',     N'Corporate Card',  1),
    (4, N'CHEQUE',   N'Cheque',          0),
    (5, N'CASH',     N'Cash on Delivery',1);
SET IDENTITY_INSERT dbo.PaymentMethods OFF;
GO

/* 6-р хэсэг - Чиглэл ба үнэ */

SET IDENTITY_INSERT dbo.Lanes ON;
INSERT INTO dbo.Lanes (LaneId, OriginTerminalId, DestinationTerminalId, DistanceKm, EstimatedDrivingHours) VALUES
    ( 1, 1, 2,  310.00,  4.50),   -- TLL -> RIX
    ( 2, 2, 1,  310.00,  4.50),   -- RIX -> TLL
    ( 3, 1, 3,  590.00,  8.00),   -- TLL -> VNO
    ( 4, 3, 1,  590.00,  8.00),
    ( 5, 2, 3,  295.00,  4.00),   -- RIX -> VNO
    ( 6, 3, 2,  295.00,  4.00),
    ( 7, 3, 5,  470.00,  6.50),   -- VNO -> WAW
    ( 8, 5, 3,  470.00,  6.50),
    ( 9, 5, 4,  340.00,  4.50),   -- WAW -> GDN
    (10, 4, 5,  340.00,  4.50),
    (11, 4, 7,  520.00,  6.50),   -- GDN -> BER
    (12, 7, 4,  520.00,  6.50),
    (13, 1, 6,   85.00,  2.50),   -- TLL -> HEL (гатлага онгоцтой тул хурд бага)
    (14, 6, 1,   85.00,  2.50),
    (15, 2, 4,  620.00,  8.50),   -- RIX -> GDN
    (16, 4, 2,  620.00,  8.50),
    (17, 3, 4,  560.00,  7.50),   -- VNO -> GDN
    (18, 4, 3,  560.00,  7.50),
    (19, 1, 5,  980.00, 13.00),   -- TLL -> WAW
    (20, 5, 1,  980.00, 13.00),
    (21, 2, 7, 1100.00, 14.00),   -- RIX -> BER
    (22, 7, 2, 1100.00, 14.00);
SET IDENTITY_INSERT dbo.Lanes OFF;
GO

-- Чиглэл x үйлчилгээ бүрт 2 үеийн үнэ: 1-р үе 800-200 хоногийн өмнө,
-- 2-р үе 200 хоногийн өмнөөс одоо хүртэл, ~6% үнэтэй (жилийн харьцуулалтад).
-- Одоогийн мөр яг нэг тул UX_LaneRates_OneCurrentRate-д таарна.
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

-- 1-р үе (хуучин үнэ)
INSERT INTO dbo.LaneRates (LaneId, ServiceLevelId, RatePerKg, MinimumCharge, FuelSurchargeRate, EffectiveFrom, EffectiveTo)
SELECT
    l.LaneId,
    sl.ServiceLevelId,
    CAST(0.0004 * l.DistanceKm + 0.0200 AS DECIMAL(9,4)),
    CAST((45.00 + l.DistanceKm * 0.09) * sl.PriceMultiplier AS DECIMAL(10,2)),
    0.0850,
    DATEADD(DAY, -800, @Today),
    DATEADD(DAY, -200, @Today)
FROM dbo.Lanes AS l
CROSS JOIN dbo.ServiceLevels AS sl;

-- 2-р үе (одоогийн үнэ)
INSERT INTO dbo.LaneRates (LaneId, ServiceLevelId, RatePerKg, MinimumCharge, FuelSurchargeRate, EffectiveFrom, EffectiveTo)
SELECT
    l.LaneId,
    sl.ServiceLevelId,
    CAST((0.0004 * l.DistanceKm + 0.0200) * 1.06 AS DECIMAL(9,4)),
    CAST((45.00 + l.DistanceKm * 0.09) * sl.PriceMultiplier * 1.06 AS DECIMAL(10,2)),
    0.1150,
    DATEADD(DAY, -200, @Today),
    NULL
FROM dbo.Lanes AS l
CROSS JOIN dbo.ServiceLevels AS sl;
GO

/* 7-р хэсэг - Харилцагчид */

DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

SET IDENTITY_INSERT dbo.Customers ON;
INSERT INTO dbo.Customers (CustomerId, CustomerCode, LegalName, TradingName, TaxNumber, BillingAddressId, CreditLimit, PaymentTermsDays, IsActive, OnboardedOn) VALUES
    ( 1, N'CUS-0001', N'Balti Ehitusmaterjalid AS',    N'Balti Build',      N'EE100234567',  8, 250000.00, 30, 1, DATEADD(MONTH, -46, @Today)),
    ( 2, N'CUS-0002', N'Nordic Cold Chain OU',          N'NordChill',       N'EE100987321',  9, 180000.00, 45, 1, DATEADD(MONTH, -38, @Today)),
    ( 3, N'CUS-0003', N'Rigas Elektronikas SIA',        N'RigaTech',        N'LV40003552189',10, 320000.00, 30, 1, DATEADD(MONTH, -41, @Today)),
    ( 4, N'CUS-0004', N'Kurzemes Kokapstrade SIA',      N'Kurzeme Timber',  N'LV40003778402',11,  95000.00, 60, 1, DATEADD(MONTH, -29, @Today)),
    ( 5, N'CUS-0005', N'Vilniaus Automobiliu Dalys UAB',N'VAD Parts',       N'LT100005412318',12, 140000.00, 30, 1, DATEADD(MONTH, -33, @Today)),
    ( 6, N'CUS-0006', N'Klaipedos Jura UAB',            N'Klaipeda Marine', N'LT100009876543',13,  75000.00, 45, 1, DATEADD(MONTH, -25, @Today)),
    ( 7, N'CUS-0007', N'Mazowieckie Chemia Sp. z o.o.', N'MazChem',         N'PL5272841930', 14, 410000.00, 30, 1, DATEADD(MONTH, -36, @Today)),
    ( 8, N'CUS-0008', N'Gdanska Logistyka Sp. z o.o.',  N'GdanskLog',       N'PL5832019477', 15, 200000.00, 30, 1, DATEADD(MONTH, -31, @Today)),
    ( 9, N'CUS-0009', N'Poznan Meble S.A.',             N'Poznan Furniture',N'PL7792140556', 16,  60000.00, 60, 1, DATEADD(MONTH, -22, @Today)),
    (10, N'CUS-0010', N'Helsinki Elintarvike Oy',       N'HelFood',         N'FI28451937',   17, 130000.00, 30, 1, DATEADD(MONTH, -27, @Today)),
    -- Dormant: удаан ачаа илгээгээгүй ("ачаа илгээхээ больсон" query-д)
    (11, N'CUS-0011', N'Berliner Maschinenbau GmbH',    N'BerMasch',        N'DE811204567',  18,  85000.00, 45, 1, DATEADD(MONTH, -34, @Today)),
    -- Хаагдсан харилцагч ("идэвхтэй харилцагч" шүүлтүүрт)
    (12, N'CUS-0012', N'Hamburg Handels GmbH',          N'HH Trading',      N'DE815339021',  19,  40000.00, 30, 0, DATEADD(MONTH, -30, @Today));
SET IDENTITY_INSERT dbo.Customers OFF;
GO

INSERT INTO dbo.CustomerContacts (CustomerId, FullName, Email, Phone, JobTitle, IsPrimary) VALUES
    ( 1, N'Tiit Ojasoo',       N'tiit.ojasoo@baltibuild.example',        N'+372 5566 1101', N'Logistics Manager',   1),
    ( 1, N'Kaisa Murumets',    N'kaisa.murumets@baltibuild.example',     N'+372 5566 1102', N'Accounts Payable',    0),
    ( 2, N'Anu Talts',         N'anu.talts@nordchill.example',           N'+372 5566 1201', N'Supply Chain Lead',   1),
    ( 3, N'Gunta Skujina',     N'gunta.skujina@rigatech.example',        N'+371 2233 1301', N'Head of Operations',  1),
    ( 3, N'Aivars Purins',     N'aivars.purins@rigatech.example',        N'+371 2233 1302', N'Finance Director',    0),
    ( 4, N'Maris Balodis',     N'maris.balodis@kurzemetimber.example',   N'+371 2233 1401', N'Export Manager',      1),
    ( 5, N'Ruta Kazlauskiene', N'ruta.k@vadparts.example',               N'+370 6677 1501', N'Purchasing Manager',  1),
    ( 5, N'Gediminas Urbonas', N'gediminas.u@vadparts.example',          N'+370 6677 1502', N'Warehouse Supervisor',0),
    ( 6, N'Vytautas Stankus',  N'vytautas.stankus@klaipedamarine.example',N'+370 6677 1601',N'Operations Director', 1),
    ( 7, N'Barbara Wojcik',    N'barbara.wojcik@mazchem.example',        N'+48 602 117 01', N'Logistics Director',  1),
    ( 7, N'Jacek Kaminski',    N'jacek.kaminski@mazchem.example',        N'+48 602 117 02', N'ADR Compliance Lead', 0),
    ( 8, N'Anna Jankowska',    N'anna.jankowska@gdansklog.example',      N'+48 602 118 01', N'Transport Planner',   1),
    ( 9, N'Michal Sikora',     N'michal.sikora@poznanfurniture.example', N'+48 602 119 01', N'Despatch Manager',    1),
    (10, N'Laura Makinen',     N'laura.makinen@helfood.example',         N'+358 45 220 101',N'Cold Chain Manager',  1),
    (11, N'Sabine Hoffmann',   N'sabine.hoffmann@bermasch.example',      N'+49 152 4400 11',N'Procurement Lead',    1),
    (12, N'Dirk Schneider',    N'dirk.schneider@hhtrading.example',      N'+49 152 4400 12',N'Managing Partner',    1);
GO

/* 8-р хэсэг - Ачаа */
-- Сүүлийн 24 сар, сард 100-аас 238 хүртэл ачаа (өсөлт харагдана).
-- Харилцагч, чиглэл жинтэй тархсан; явалт сарын 1, 8, 15, 22-нд тул рейст нэгтгэж болно.
-- NEXT VALUE FOR нь ROW_NUMBER-тэй хамт болохгүй тул tracking дугаарыг тооцоолж гаргана.

DECLARE @Today      DATE = CAST(SYSUTCDATETIME() AS DATE);
DECLARE @ThisMonth  DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);

-- Харилцагчийн жин: Lo..Hi нь 100-аас bucket (топ 3 нь ~45%)
DECLARE @CustomerWeights TABLE (Lo INT NOT NULL, Hi INT NOT NULL, CustomerId INT NOT NULL);
INSERT INTO @CustomerWeights (Lo, Hi, CustomerId) VALUES
    ( 0, 17,  1),   -- 18%
    (18, 31,  3),   -- 14%
    (32, 44,  7),   -- 13%
    (45, 55,  2),   -- 11%
    (56, 64,  8),   --  9%
    (65, 72,  5),   --  8%
    (73, 79, 10),   --  7%
    (80, 85,  4),   --  6%
    (86, 90,  6),   --  5%
    (91, 94,  9),   --  4%
    (95, 97, 11),   --  3% (dormant, доор зогсоно)
    (98, 99, 12);   --  2% (хаагдсан, доор зогсоно)

-- Чиглэлийн жин: найман гол чиглэл ачааны 64%
DECLARE @LaneWeights TABLE (Lo INT NOT NULL, Hi INT NOT NULL, LaneId INT NOT NULL);
INSERT INTO @LaneWeights (Lo, Hi, LaneId) VALUES
    ( 0,  8,  1), ( 9, 17,  2),     -- TLL <-> RIX   гол чиглэл
    (18, 25,  5), (26, 33,  6),     -- RIX <-> VNO   гол чиглэл
    (34, 41,  9), (42, 49, 10),     -- WAW <-> GDN   гол чиглэл
    (50, 56, 15), (57, 63, 16),     -- RIX <-> GDN   гол чиглэл
    (64, 67,  3), (68, 71,  4),     -- TLL <-> VNO
    (72, 75,  7), (76, 79,  8),     -- VNO <-> WAW
    (80, 82, 11), (83, 85, 12),     -- GDN <-> BER
    (86, 88, 17), (89, 91, 18),     -- VNO <-> GDN
    (92, 93, 13), (94, 95, 14),     -- TLL <-> HEL
    (96, 96, 19), (97, 97, 20),     -- TLL <-> WAW  урт зай
    (98, 98, 21), (99, 99, 22);     -- RIX <-> BER  урт зай

-- Терминал бүрийн хаягууд; Cnt мөрөнд байгаа тул modulo-оор slot сонгоно.
DECLARE @TerminalAddresses TABLE
(
    TerminalId INT NOT NULL,
    Slot       INT NOT NULL,
    Cnt        INT NOT NULL,
    AddressId  INT NOT NULL,
    PRIMARY KEY (TerminalId, Slot)
);
INSERT INTO @TerminalAddresses (TerminalId, Slot, Cnt, AddressId) VALUES
    (1, 0, 6, 20), (1, 1, 6, 21), (1, 2, 6, 22), (1, 3, 6, 23), (1, 4, 6, 44), (1, 5, 6, 49),
    (2, 0, 5, 24), (2, 1, 5, 25), (2, 2, 5, 26), (2, 3, 5, 27), (2, 4, 5, 45),
    (3, 0, 5, 28), (3, 1, 5, 29), (3, 2, 5, 30), (3, 3, 5, 31), (3, 4, 5, 46),
    (4, 0, 4, 34), (4, 1, 4, 35), (4, 2, 4, 36), (4, 3, 4, 47),
    (5, 0, 2, 32), (5, 1, 2, 33),
    (6, 0, 4, 37), (6, 1, 4, 38), (6, 2, 4, 39), (6, 3, 4, 48),
    (7, 0, 4, 40), (7, 1, 4, 41), (7, 2, 4, 42), (7, 3, 4, 43);

INSERT INTO dbo.Shipments
(
    TrackingNumber, CustomerId, LaneId, ServiceLevelId, CargoCategoryId,
    OriginAddressId, DestinationAddressId, BookedAt, PickupDate, PromisedDeliveryDate,
    Status, TotalWeightKg, TotalVolumeM3, DeclaredValue,
    FreightCharge, SurchargeAmount, TaxAmount, IsInsured
)
SELECT
    N'NF' + RIGHT(N'00000000' + CAST(10000000 + g.n AS NVARCHAR(10)), 8),
    g.CustomerId,
    g.LaneId,
    g.ServiceLevelId,
    g.CargoCategoryId,
    g.OriginAddressId,
    g.DestinationAddressId,
    DATEADD(HOUR, -(6 + (g.n % 60)), CAST(g.PickupDate AS DATETIME2(3))),
    g.PickupDate,
    DATEADD(DAY, sl.MaxTransitDays, g.PickupDate),
    N'Booked',              -- төлвийг доор ахиулна
    1.00, 0.001, 0,         -- түр утга, доор бодогдоно
    0, 0, 0,
    CASE WHEN g.n % 7 = 0 THEN 1 ELSE 0 END
FROM
(
    SELECT
        ROW_NUMBER() OVER (ORDER BY m.MonthOffset, k.Seq)            AS n,
        cw.CustomerId,
        lw.LaneId,
        -- өөр өөр prime ашигласан, эс бөгөөс баганууд нэг хэмнэлээр давтагдана
        CASE ((m.MonthOffset * 3 + k.Seq * 29) % 10)
            WHEN 0 THEN 1 WHEN 1 THEN 1              -- 20% Economy
            WHEN 2 THEN 3 WHEN 3 THEN 3              -- 20% Express
            WHEN 4 THEN 4                            -- 10% Next Day
            ELSE 2                                   -- 50% Standard
        END                                                          AS ServiceLevelId,
        -- modulo биш hash: modulo бол аюултай, хөргөлттэй ачаа нэг өдөр бөөгнөрнө (hash ч deterministic)
        1 + ABS(CAST(HASHBYTES('SHA2_256', CONCAT('cargo', m.MonthOffset, '-', k.Seq)) AS INT) % 8)
                                                                     AS CargoCategoryId,
        oa.AddressId                                                 AS OriginAddressId,
        da.AddressId                                                 AS DestinationAddressId,
        -- сарын 1, 8, 15 эсвэл 22-нд явна
        DATEADD(DAY,
                ((k.Seq * 7919) % 4) * 7,
                DATEADD(MONTH, m.MonthOffset - 23, @ThisMonth))      AS PickupDate,
        m.MonthOffset
    FROM (SELECT TOP (24) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS MonthOffset
          FROM sys.all_objects) AS m
    CROSS JOIN (SELECT TOP (240) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Seq
                FROM sys.all_objects) AS k
    INNER JOIN @CustomerWeights AS cw
            ON ((m.MonthOffset * 37 + k.Seq * 61) % 100) BETWEEN cw.Lo AND cw.Hi
    INNER JOIN @LaneWeights AS lw
            ON ((m.MonthOffset * 19 + k.Seq * 83) % 100) BETWEEN lw.Lo AND lw.Hi
    INNER JOIN dbo.Lanes AS ln ON ln.LaneId = lw.LaneId
    INNER JOIN @TerminalAddresses AS oa
            ON oa.TerminalId = ln.OriginTerminalId
           AND oa.Slot = ((m.MonthOffset * 13 + k.Seq * 31) % oa.Cnt)
    INNER JOIN @TerminalAddresses AS da
            ON da.TerminalId = ln.DestinationTerminalId
           AND da.Slot = ((m.MonthOffset * 17 + k.Seq * 41) % da.Cnt)
    -- сард 100-аас 238 хүртэл өснө
    WHERE k.Seq <= 100 + (m.MonthOffset * 6)
      -- 11 нь 10 сарын өмнө зогссон, 12 нь 14 сарын өмнө хаагдсан
      AND NOT (cw.CustomerId = 11 AND m.MonthOffset > 13)
      AND NOT (cw.CustomerId = 12 AND m.MonthOffset >  9)
) AS g
INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = g.ServiceLevelId
-- CK_Shipments_DistinctEndpoints-д нэмэлт хамгаалалт (уг нь юу ч шүүхгүй)
WHERE g.OriginAddressId <> g.DestinationAddressId;

DECLARE @TrunkInserted INT = @@ROWCOUNT;

-- Сүүлийн 6, дараагийн 2 өдрийн express ачаа. Ингэхгүй бол сарын хэдэнд ажиллуулснаас
-- хамаарч PickedUp, InTransit хоосон гарна (тестүүд, fn_ShipmentsAtRisk-д хэрэгтэй).

DECLARE @MaxTrack INT =
(
    SELECT ISNULL(MAX(CAST(SUBSTRING(TrackingNumber, 3, 8) AS INT)), 10000000)
    FROM dbo.Shipments
);

INSERT INTO dbo.Shipments
(
    TrackingNumber, CustomerId, LaneId, ServiceLevelId, CargoCategoryId,
    OriginAddressId, DestinationAddressId, BookedAt, PickupDate, PromisedDeliveryDate,
    Status, TotalWeightKg, TotalVolumeM3, DeclaredValue,
    FreightCharge, SurchargeAmount, TaxAmount, IsInsured
)
SELECT
    N'NF' + RIGHT(N'00000000' + CAST(@MaxTrack + x.rn AS NVARCHAR(10)), 8),
    1 + ((x.rn * 5) % 10),                          -- идэвхтэй харилцагч 1-10
    tl.LaneId,
    CASE WHEN x.rn % 3 = 0 THEN 4 ELSE 3 END,       -- Next Day эсвэл Express
    1 + ((x.rn * 3) % 8),
    oa.AddressId,
    da.AddressId,
    DATEADD(HOUR, -14, CAST(DATEADD(DAY, x.DayOffset, @Today) AS DATETIME2(3))),
    DATEADD(DAY, x.DayOffset, @Today),
    DATEADD(DAY, x.DayOffset + sl.MaxTransitDays, @Today),
    N'Booked',
    1.00, 0.001, 0,
    0, 0, 0,
    0
FROM
(
    SELECT ROW_NUMBER() OVER (ORDER BY d.DayOffset, k.Seq) AS rn,
           d.DayOffset,
           k.Seq
    FROM (VALUES (-6), (-5), (-4), (-3), (-2), (-1), (0), (1), (2)) AS d (DayOffset)
    CROSS JOIN (VALUES (1), (2), (3), (4), (5)) AS k (Seq)
) AS x
-- Express нь гол чиглэлүүдээр явна
INNER JOIN (VALUES (1, 1), (2, 2), (3, 5), (4, 6), (5, 9), (6, 10), (7, 15), (8, 16))
        AS tl (Slot, LaneId) ON tl.Slot = 1 + (x.rn % 8)
INNER JOIN dbo.Lanes         AS ln ON ln.LaneId         = tl.LaneId
INNER JOIN dbo.ServiceLevels AS sl ON sl.ServiceLevelId = CASE WHEN x.rn % 3 = 0 THEN 4 ELSE 3 END
INNER JOIN @TerminalAddresses AS oa
        ON oa.TerminalId = ln.OriginTerminalId      AND oa.Slot = (x.rn * 7) % oa.Cnt
INNER JOIN @TerminalAddresses AS da
        ON da.TerminalId = ln.DestinationTerminalId AND da.Slot = (x.rn * 11) % da.Cnt;

PRINT 'Shipments inserted: ' + CAST(@TrunkInserted AS VARCHAR(10))
    + ' trunk + ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' express';
GO

-- Sequence-ийг урагшлуулна, эс бөгөөс usp_CreateShipment давхар tracking дугаар олгоно.
DECLARE @NextTracking INT = (SELECT MAX(CAST(SUBSTRING(TrackingNumber, 3, 8) AS INT)) + 1 FROM dbo.Shipments);
DECLARE @Sql NVARCHAR(200) =
    N'ALTER SEQUENCE dbo.seq_TrackingNumber RESTART WITH ' + CAST(@NextTracking AS NVARCHAR(20)) + N';';
EXEC sys.sp_executesql @Sql;
GO

-- Ачааны бараа: ачаа бүрт 1-4 мөр, тайлбар нь ангилалдаа тохирсон.
DECLARE @ItemNames TABLE
(
    CargoCategoryId INT           NOT NULL,
    Slot            INT           NOT NULL,
    Description     NVARCHAR(200) NOT NULL,
    PackagingType   NVARCHAR(20)  NOT NULL,
    PRIMARY KEY (CargoCategoryId, Slot)
);
INSERT INTO @ItemNames (CargoCategoryId, Slot, Description, PackagingType) VALUES
    (1, 0, N'Mixed general cargo',              N'Pallet'),
    (1, 1, N'Assorted dry goods',               N'Box'),
    (1, 2, N'Packaging materials',              N'Roll'),
    (2, 0, N'Euro pallets, stretch wrapped',    N'Pallet'),
    (2, 1, N'Stacked block pallets',            N'Pallet'),
    (2, 2, N'Palletised cartons',               N'Pallet'),
    (3, 0, N'Flat glass panels, crated',        N'Crate'),
    (3, 1, N'Ceramic sanitary ware',            N'Crate'),
    (3, 2, N'Laboratory glassware',             N'Box'),
    (4, 0, N'Chilled dairy products (+2C)',     N'Pallet'),
    (4, 1, N'Fresh produce, temperature controlled', N'Crate'),
    (4, 2, N'Chilled ready meals',              N'Pallet'),
    (5, 0, N'Frozen fish fillets (-18C)',       N'Pallet'),
    (5, 1, N'Frozen bakery products',           N'Box'),
    (5, 2, N'Ice cream, deep frozen',           N'Pallet'),
    (6, 0, N'UN1263 Paint, class 3',            N'Drum'),
    (6, 1, N'UN1993 Flammable liquid n.o.s.',   N'Drum'),
    (6, 2, N'UN1830 Sulphuric acid, class 8',   N'Drum'),
    (7, 0, N'Brake discs and pads',             N'Box'),
    (7, 1, N'Engine components, palletised',    N'Pallet'),
    (7, 2, N'Vehicle body panels',              N'Crate'),
    (8, 0, N'Consumer electronics, boxed',      N'Box'),
    (8, 1, N'Server hardware, anti-static',     N'Crate'),
    (8, 2, N'Cable assemblies',                 N'Bag');

INSERT INTO dbo.ShipmentItems
    (ShipmentId, LineNumber, Description, Quantity, UnitWeightKg, UnitVolumeM3, PackagingType)
SELECT
    s.ShipmentId,
    t.LineIdx,
    inm.Description,
    -- хамгийн хүнд ачаа 6,912 kg, гурав нь 22 t-д багтана (TR_TripShipments_EnforceCapacity)
    1 + CAST((s.ShipmentId * 7 + t.LineIdx * 13) % 12 AS INT),
    CAST(25 + ((s.ShipmentId * 11 + t.LineIdx * 29) % 120) AS DECIMAL(9,3)),
    CAST(0.12 + (((s.ShipmentId * 17 + t.LineIdx * 23) % 30) / 100.0) AS DECIMAL(9,4)),
    inm.PackagingType
FROM dbo.Shipments AS s
CROSS JOIN (VALUES (1), (2), (3), (4)) AS t (LineIdx)
INNER JOIN @ItemNames AS inm
        ON inm.CargoCategoryId = s.CargoCategoryId
       AND inm.Slot = (s.ShipmentId + t.LineIdx) % 3
-- ачаа бүрт нэгээс дөрвөн мөр
WHERE t.LineIdx <= 1 + (s.ShipmentId % 4);

PRINT 'Shipment items inserted: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- Барааны жин, эзэлхүүнийг ачаан дээр нэгтгэнэ (usp_CreateShipment шиг).
UPDATE s
SET s.TotalWeightKg = i.WeightKg,
    s.TotalVolumeM3 = i.VolumeM3
FROM dbo.Shipments AS s
CROSS APPLY
(
    SELECT CAST(SUM(si.LineWeightKg) AS DECIMAL(10,2)) AS WeightKg,
           CAST(SUM(si.LineVolumeM3) AS DECIMAL(10,3)) AS VolumeM3
    FROM dbo.ShipmentItems AS si
    WHERE si.ShipmentId = s.ShipmentId
) AS i;
GO

-- Үнийг захиалгынхтай ижил функцээр бодно, тэгэхээр орлого үнийн жагсаалттай таарна.
UPDATE s
SET s.FreightCharge   = q.FreightCharge,
    s.SurchargeAmount = q.SurchargeAmount,
    s.TaxAmount       = q.TaxAmount,
    s.DeclaredValue   = CASE WHEN s.ShipmentId % 7 = 0
                             THEN CAST(q.TotalAmount * 12 AS DECIMAL(12,2))
                             ELSE 0 END
FROM dbo.Shipments AS s
CROSS APPLY dbo.fn_QuoteShipment(s.LaneId, s.ServiceLevelId, s.CargoCategoryId,
                                 s.TotalWeightKg, s.PickupDate) AS q;
GO

-- CargoCategories-ийн зарласан үнийн дээд хязгаарыг мөрдөнө
UPDATE s
SET s.DeclaredValue = cc.MaxDeclaredValue
FROM dbo.Shipments AS s
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE cc.MaxDeclaredValue IS NOT NULL
  AND s.DeclaredValue > cc.MaxDeclaredValue;
GO

-- Төлвийг үе шаттай UPDATE-ээр ахиулна: TR_Shipments_TrackStatus жинхэнэ түүх бичнэ.
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

-- ~3% нь ачааг авахаас өмнө цуцлагдсан
UPDATE dbo.Shipments
SET Status = N'Cancelled'
WHERE PickupDate < DATEADD(DAY, -10, @Today)
  AND ShipmentId % 33 = 0;

UPDATE dbo.Shipments
SET Status = N'PickedUp'
WHERE Status = N'Booked' AND PickupDate <= @Today;

UPDATE dbo.Shipments
SET Status = N'InTransit'
WHERE Status = N'PickedUp' AND PickupDate <= DATEADD(DAY, -2, @Today);

UPDATE dbo.Shipments
SET Status = N'OutForDelivery'
WHERE Status = N'InTransit' AND PickupDate <= DATEADD(DAY, -4, @Today);

-- ~2% нь асуудалтай, шийдэгдээгүй
UPDATE dbo.Shipments
SET Status = N'Exception'
WHERE Status = N'OutForDelivery'
  AND PickupDate < DATEADD(DAY, -15, @Today)
  AND ShipmentId % 47 = 0;

-- Хугацаа нь өнгөрсөн ачаа хүргэгдэнэ: ~20% эрт, ~65% цагтаа, ~15% 1-3 өдөр хоцорно.
UPDATE s
SET s.Status = N'Delivered',
    s.ActualDeliveryDate =
        CASE
            WHEN DATEADD(DAY, o.Days, s.PromisedDeliveryDate) < f.EarliestDelivery
                THEN f.EarliestDelivery
            ELSE DATEADD(DAY, o.Days, s.PromisedDeliveryDate)
        END
FROM dbo.Shipments AS s
INNER JOIN dbo.Lanes AS l ON l.LaneId = s.LaneId
CROSS APPLY
(
    SELECT CASE
               WHEN s.ShipmentId % 100 < 20 THEN -1
               WHEN s.ShipmentId % 100 < 85 THEN  0
               ELSE 1 + (s.ShipmentId % 3)
           END AS Days
) AS o
-- Машин очихоос өмнө хүргэж болохгүй: 12 цагаас урт рейс хамгийн эртдээ маргааш нь очно.
CROSS APPLY
(
    SELECT DATEADD(DAY, CASE WHEN l.EstimatedDrivingHours > 12 THEN 1 ELSE 0 END, s.PickupDate)
               AS EarliestDelivery
) AS f
WHERE s.Status = N'OutForDelivery'
  AND s.PromisedDeliveryDate <= DATEADD(DAY, -5, @Today);

PRINT 'Shipment lifecycle applied.';
GO

-- Trigger түүхийг "одоо" гэж бичсэн тул цагийг ачааны жинхэнэ хугацаанд тарааж өгнө.
UPDATE h
SET h.ChangedAt =
    CASE h.NewStatus
        WHEN N'Booked'         THEN CAST(s.BookedAt AS DATETIME2(3))
        WHEN N'PickedUp'       THEN DATEADD(HOUR,  9, CAST(s.PickupDate AS DATETIME2(3)))
        WHEN N'InTransit'      THEN DATEADD(HOUR, 30, CAST(s.PickupDate AS DATETIME2(3)))
        WHEN N'OutForDelivery' THEN DATEADD(HOUR, -6, CAST(ISNULL(s.ActualDeliveryDate,
                                                           s.PromisedDeliveryDate) AS DATETIME2(3)))
        WHEN N'Delivered'      THEN DATEADD(HOUR, 11, CAST(s.ActualDeliveryDate AS DATETIME2(3)))
        WHEN N'Cancelled'      THEN DATEADD(HOUR, -4, CAST(s.PickupDate AS DATETIME2(3)))
        WHEN N'Exception'      THEN DATEADD(HOUR, 40, CAST(s.PickupDate AS DATETIME2(3)))
        ELSE h.ChangedAt
    END
FROM dbo.ShipmentStatusHistory AS h
INNER JOIN dbo.Shipments AS s ON s.ShipmentId = h.ShipmentId;
GO

/* 9-р хэсэг - Рейс, жолооч, одометр, засвар үйлчилгээ */
-- Нэг чиглэл, нэг өдрийн ачааг рейс бүрт 3 хүртэл нэгтгэнэ (22-24 t даацад багтана).
-- Өдрийн n-р рейс n-р машин, n-р ээлж n-р жолоочийг авна: давхардалгүй, дутвал алдаа өгнө.
-- Одометр = анхны заалт + өдөрт 40 км + өмнөх рейс бүрт (зай + 250 км).

DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

-- Группүүд: (чиглэл, pickup огноо, reefer эсэх), гурав гураваар
SELECT
    s.ShipmentId,
    s.LaneId,
    s.PickupDate,
    l.OriginTerminalId,
    l.DestinationTerminalId,
    l.DistanceKm,
    l.EstimatedDrivingHours,
    cc.RequiresRefrigeration,
    -- группийн дотор 1,1,1,2,2,2,3... => рейс бүрт гурван ачаа
    (ROW_NUMBER() OVER (PARTITION BY s.LaneId, s.PickupDate, cc.RequiresRefrigeration
                        ORDER BY s.ShipmentId) + 2) / 3 AS GroupNo,
    ROW_NUMBER() OVER (PARTITION BY s.LaneId, s.PickupDate, cc.RequiresRefrigeration
                       ORDER BY s.ShipmentId)           AS SeqInGroup
INTO #TripCandidates
FROM dbo.Shipments AS s
INNER JOIN dbo.Lanes           AS l  ON l.LaneId          = s.LaneId
INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
WHERE s.Status IN (N'InTransit', N'OutForDelivery', N'Delivered', N'Exception');

-- Төлөвлөсөн рейс бүрт нэг мөр
SELECT
    ROW_NUMBER() OVER (ORDER BY c.PickupDate, c.LaneId, c.RequiresRefrigeration, c.GroupNo) AS TripSeq,
    c.LaneId,
    c.PickupDate,
    c.OriginTerminalId,
    c.DestinationTerminalId,
    c.DistanceKm,
    c.EstimatedDrivingHours,
    c.RequiresRefrigeration,
    c.GroupNo
INTO #TripGroups
FROM #TripCandidates AS c
GROUP BY c.LaneId, c.PickupDate, c.OriginTerminalId, c.DestinationTerminalId,
         c.DistanceKm, c.EstimatedDrivingHours, c.RequiresRefrigeration, c.GroupNo;

-- Машин хуваарилалт: өдрийн n-р рейс өөрийн pool-ийн n-р машиныг авна
WITH DaySlots AS
(
    SELECT g.TripSeq,
           g.RequiresRefrigeration,
           ROW_NUMBER() OVER (PARTITION BY g.PickupDate, g.RequiresRefrigeration
                              ORDER BY g.OriginTerminalId, g.TripSeq) AS Slot
    FROM #TripGroups AS g
),
VehiclePool AS
(
    SELECT v.VehicleId,
           vt.IsRefrigerated,
           ROW_NUMBER() OVER (PARTITION BY vt.IsRefrigerated
                              ORDER BY v.HomeTerminalId, v.VehicleId) AS Slot
    FROM dbo.Vehicles AS v
    INNER JOIN dbo.VehicleTypes AS vt ON vt.VehicleTypeId = v.VehicleTypeId
    WHERE vt.TypeCode IN (N'ARTIC', N'REEFER')
      AND v.Status = N'Available'
)
SELECT ds.TripSeq, vp.VehicleId
INTO #TripVehicle
FROM DaySlots AS ds
INNER JOIN VehiclePool AS vp
        ON vp.IsRefrigerated = ds.RequiresRefrigeration
       AND vp.Slot           = ds.Slot;

IF (SELECT COUNT(*) FROM #TripVehicle) <> (SELECT COUNT(*) FROM #TripGroups)
    THROW 50091, 'The fleet is too small for the busiest departure day. Add vehicles in Section 4.', 1;

-- машин бүрийн одометрийн эхлэх утга
SELECT v.VehicleId,
       90000 + (v.VehicleId * 7919) % 260000 AS BaseKm,
       DATEADD(DAY, -800, @Today)            AS OriginDate
INTO #VehicleBase
FROM dbo.Vehicles AS v;

INSERT INTO dbo.Trips
(
    TripNumber, VehicleId, OriginTerminalId, DestinationTerminalId,
    ScheduledDeparture, ScheduledArrival, ActualDeparture, ActualArrival,
    StartOdometerKm, EndOdometerKm, FuelLitres, Status
)
SELECT
    N'TRP-' + RIGHT(N'00000' + CAST(30000 + p.TripSeq AS NVARCHAR(10)), 5),
    p.VehicleId,
    p.OriginTerminalId,
    p.DestinationTerminalId,
    dep.ScheduledDeparture,
    DATEADD(MINUTE, CAST(p.EstimatedDrivingHours * 60 AS INT), dep.ScheduledDeparture),
    -- гарах 0-50, ирэх 0-95 минут хоцорно
    DATEADD(MINUTE, (p.TripSeq * 17) % 50, dep.ScheduledDeparture),
    DATEADD(MINUTE, CAST(p.EstimatedDrivingHours * 60 AS INT) + ((p.TripSeq * 23) % 95),
            dep.ScheduledDeparture),
    odo.StartKm,
    odo.StartKm + CAST(p.DistanceKm AS INT),
    CAST(p.DistanceKm * (0.28 + ((p.TripSeq % 9) / 100.0)) AS DECIMAL(9,2)),
    N'Completed'
FROM
(
    SELECT g.TripSeq, g.PickupDate, g.OriginTerminalId, g.DestinationTerminalId,
           g.DistanceKm, g.EstimatedDrivingHours,
           tv.VehicleId, vb.BaseKm, vb.OriginDate,
           -- өмнөх рейсүүдэд туулсан зай
           ISNULL(SUM(CAST(g.DistanceKm AS INT) + 250)
                  OVER (PARTITION BY tv.VehicleId
                        ORDER BY g.PickupDate, g.TripSeq
                        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0) AS PriorTripKm
    FROM #TripGroups AS g
    INNER JOIN #TripVehicle AS tv ON tv.TripSeq   = g.TripSeq
    INNER JOIN #VehicleBase AS vb ON vb.VehicleId = tv.VehicleId
) AS p
CROSS APPLY
(
    SELECT CAST(DATEADD(HOUR, 6 + (p.TripSeq % 5), CAST(p.PickupDate AS DATETIME2(0)))
                AS DATETIME2(0)) AS ScheduledDeparture
) AS dep
CROSS APPLY
(
    SELECT p.BaseKm + 40 * DATEDIFF(DAY, p.OriginDate, p.PickupDate) + p.PriorTripKm AS StartKm
) AS odo;

PRINT 'Trips inserted: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- Ачааны жагсаалт: рейс бүрийг 1-3 ачаатай холбоно
INSERT INTO dbo.TripShipments (TripId, ShipmentId, StopSequence, LegType, LoadedAt, UnloadedAt)
SELECT
    t.TripId,
    c.ShipmentId,
    CAST(c.SeqInGroup - ((c.GroupNo - 1) * 3) AS SMALLINT),
    N'LineHaul',
    t.ActualDeparture,
    t.ActualArrival
FROM #TripCandidates AS c
INNER JOIN #TripGroups AS g
        ON g.LaneId                = c.LaneId
       AND g.PickupDate            = c.PickupDate
       AND g.GroupNo               = c.GroupNo
       AND g.RequiresRefrigeration = c.RequiresRefrigeration
INNER JOIN dbo.Trips AS t
        ON t.TripNumber = N'TRP-' + RIGHT(N'00000' + CAST(30000 + g.TripSeq AS NVARCHAR(10)), 5);

PRINT 'Trip manifest rows inserted: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
GO

-- seq_TripNumber-ийг урагшлуулна, эс бөгөөс usp_DispatchTrip UQ_Trips_Number дээр алдаа өгнө.
DECLARE @NextTrip INT = (SELECT MAX(CAST(SUBSTRING(TripNumber, 5, 5) AS INT)) + 1 FROM dbo.Trips);
DECLARE @Sql NVARCHAR(200) =
    N'ALTER SEQUENCE dbo.seq_TripNumber RESTART WITH ' + CAST(@NextTrip AS NVARCHAR(20)) + N';';
EXEC sys.sp_executesql @Sql;
GO

-- Жолооч хуваарилалт: аюултай ачааны ээлж ADR жолоочид түрүүлж оногдоно.
WITH TripFacts AS
(
    SELECT
        t.TripId,
        CAST(t.ScheduledDeparture AS DATE) AS DepartDate,
        t.OriginTerminalId,
        l.DistanceKm,
        CASE WHEN EXISTS
             (
                 SELECT 1
                 FROM dbo.TripShipments         AS ts
                 INNER JOIN dbo.Shipments       AS s  ON s.ShipmentId       = ts.ShipmentId
                 INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
                 WHERE ts.TripId = t.TripId
                   AND cc.RequiresHazmat = 1
             )
             THEN 1 ELSE 0
        END AS IsHazmat
    FROM dbo.Trips AS t
    INNER JOIN dbo.Lanes AS l
            ON l.OriginTerminalId      = t.OriginTerminalId
           AND l.DestinationTerminalId = t.DestinationTerminalId
),
Shifts AS
(
    SELECT TripId, DepartDate, OriginTerminalId, IsHazmat, N'Primary' AS DriverRole, 0 AS RoleOrder
    FROM TripFacts
    UNION ALL
    SELECT TripId, DepartDate, OriginTerminalId, IsHazmat, N'CoDriver', 1
    FROM TripFacts
    WHERE DistanceKm > 500
),
NumberedShifts AS
(
    SELECT TripId,
           DepartDate,
           DriverRole,
           ROW_NUMBER() OVER (PARTITION BY DepartDate
                              ORDER BY IsHazmat DESC, RoleOrder, OriginTerminalId, TripId) AS Slot
    FROM Shifts
),
Roster AS
(
    SELECT d.DepartDate,
           dr.DriverId,
           ROW_NUMBER() OVER (PARTITION BY d.DepartDate
                              ORDER BY dr.HasHazmatEndorsement DESC, e.HomeTerminalId, dr.DriverId) AS Slot
    FROM (SELECT DISTINCT DepartDate FROM TripFacts) AS d
    CROSS JOIN dbo.Drivers AS dr
    INNER JOIN dbo.Employees AS e ON e.EmployeeId = dr.DriverId
    WHERE dr.LicenceClass         = 'CE'
      AND dr.LicenceIssuedOn     <= d.DepartDate
      AND dr.LicenceExpiresOn     > d.DepartDate
      AND dr.MedicalCertExpiresOn > d.DepartDate
      AND e.HireDate             <= d.DepartDate
      AND (e.TerminationDate IS NULL OR e.TerminationDate > d.DepartDate)
)
INSERT INTO dbo.TripDrivers (TripId, DriverId, DriverRole, AssignedAt)
SELECT ns.TripId, r.DriverId, ns.DriverRole, DATEADD(DAY, -1, t.ScheduledDeparture)
FROM NumberedShifts AS ns
INNER JOIN Roster    AS r ON r.DepartDate = ns.DepartDate AND r.Slot = ns.Slot
INNER JOIN dbo.Trips AS t ON t.TripId     = ns.TripId;

DECLARE @ExpectedShifts INT =
(
    SELECT COUNT(*) + SUM(CASE WHEN l.DistanceKm > 500 THEN 1 ELSE 0 END)
    FROM dbo.Trips AS t
    INNER JOIN dbo.Lanes AS l
            ON l.OriginTerminalId      = t.OriginTerminalId
           AND l.DestinationTerminalId = t.DestinationTerminalId
);

IF (SELECT COUNT(*) FROM dbo.TripDrivers) <> @ExpectedShifts
    THROW 50092, 'The driver roster is too small for the busiest departure day. Add drivers in Section 3.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.TripDrivers AS td
    INNER JOIN dbo.Drivers AS d ON d.DriverId = td.DriverId
    WHERE d.HasHazmatEndorsement = 0
      AND EXISTS (SELECT 1
                  FROM dbo.TripShipments         AS ts
                  INNER JOIN dbo.Shipments       AS s  ON s.ShipmentId       = ts.ShipmentId
                  INNER JOIN dbo.CargoCategories AS cc ON cc.CargoCategoryId = s.CargoCategoryId
                  WHERE ts.TripId = td.TripId
                    AND cc.RequiresHazmat = 1)
)
    THROW 50093, 'Not enough ADR-endorsed drivers to crew every dangerous-goods trip.', 1;

PRINT 'Trip crew rows inserted: ' + CAST(@ExpectedShifts AS VARCHAR(10));
GO

-- Одоогийн одометр болон засварын түүх, хоёулаа нэг томьёогоор.
DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

UPDATE v
SET v.OdometerKm = vb.BaseKm
                 + 40 * DATEDIFF(DAY, vb.OriginDate, @Today)
                 + ISNULL(tk.TripKm, 0)
FROM dbo.Vehicles AS v
INNER JOIN #VehicleBase AS vb ON vb.VehicleId = v.VehicleId
OUTER APPLY
(
    SELECT SUM(t.EndOdometerKm - t.StartOdometerKm + 250) AS TripKm
    FROM dbo.Trips AS t
    WHERE t.VehicleId = v.VehicleId
) AS tk;

-- Машин бүр 4 удаа засварт: сарын 4, 11, 18, 25-нд, 36 цаг хүртэл тул рейстэй давхцахгүй.
INSERT INTO dbo.MaintenanceRecords
    (VehicleId, MaintenanceType, PerformedOn, OdometerKm, LabourCost, PartsCost, DownTimeHours, Notes)
SELECT
    v.VehicleId,
    CASE (v.VehicleId * 3 + n.Seq) % 5
        WHEN 0 THEN N'Scheduled'
        WHEN 1 THEN N'Inspection'
        WHEN 2 THEN N'Repair'
        WHEN 3 THEN N'TyreChange'
        ELSE        N'Bodywork'
    END,
    m.PerformedOn,
    vb.BaseKm
        + 40 * DATEDIFF(DAY, vb.OriginDate, m.PerformedOn)
        + ISNULL((SELECT SUM(t.EndOdometerKm - t.StartOdometerKm + 250)
                  FROM dbo.Trips AS t
                  WHERE t.VehicleId = v.VehicleId
                    AND CAST(t.ScheduledDeparture AS DATE) < m.PerformedOn), 0),
    CAST(120 + ((v.VehicleId * 47 + n.Seq * 91) % 640)  AS DECIMAL(10,2)),
    CAST( 80 + ((v.VehicleId * 83 + n.Seq * 59) % 1900) AS DECIMAL(10,2)),
    CAST(  2 + ((v.VehicleId * 11 + n.Seq * 17) % 34)   AS DECIMAL(6,2)),
    CASE (v.VehicleId * 3 + n.Seq) % 5
        WHEN 0 THEN N'Routine service at scheduled interval.'
        WHEN 1 THEN N'Annual roadworthiness inspection passed.'
        WHEN 2 THEN N'Unplanned repair - vehicle off road.'
        WHEN 3 THEN N'Drive axle tyres replaced.'
        ELSE        N'Bodywork and curtain repair after minor damage.'
    END
FROM dbo.Vehicles AS v
INNER JOIN #VehicleBase AS vb ON vb.VehicleId = v.VehicleId
CROSS JOIN (VALUES (1), (2), (3), (4)) AS n (Seq)
CROSS APPLY
(
    SELECT DATEADD(DAY, 3 + ((v.VehicleId + n.Seq) % 4) * 7,
                   DATEADD(MONTH, -(n.Seq * 5 + v.VehicleId % 3),
                           DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1))) AS PerformedOn
) AS m;

-- 13-р машин одоо засварт (InMaintenance)
INSERT INTO dbo.MaintenanceRecords
    (VehicleId, MaintenanceType, PerformedOn, OdometerKm, LabourCost, PartsCost, DownTimeHours, Notes)
SELECT v.VehicleId, N'Repair', DATEADD(DAY, -1, @Today), v.OdometerKm - 40,
       380.00, 2450.00, 48.00, N'Gearbox fault - vehicle off road, repair in progress.'
FROM dbo.Vehicles AS v
WHERE v.VehicleId = 13;

PRINT 'Odometers set and maintenance history generated.';
GO

DROP TABLE #TripCandidates;
DROP TABLE #TripGroups;
DROP TABLE #TripVehicle;
DROP TABLE #VehicleBase;
GO

/* 10-р хэсэг - Нэхэмжлэх */
-- usp_GenerateCustomerInvoice-ийг харилцагч, сар бүрт дуудна, тэгэхээр бүх дүрэм мөрдөгдөнө.
-- Сүүлийн сарыг "хүргэгдсэн ч нэхэмжлээгүй" query-д зориулж үлдээсэн.

DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

-- Нэхэмжлээгүй хүргэлттэй харилцагч + сар
SELECT
    ROW_NUMBER() OVER (ORDER BY MonthStart, CustomerId) AS RowNo,
    CustomerId,
    MonthStart,
    EOMONTH(MonthStart) AS MonthEnd
INTO #ToInvoice
FROM
(
    SELECT DISTINCT
           s.CustomerId,
           DATEFROMPARTS(YEAR(s.ActualDeliveryDate), MONTH(s.ActualDeliveryDate), 1) AS MonthStart
    FROM dbo.Shipments AS s
    WHERE s.Status = N'Delivered'
      AND s.ActualDeliveryDate < DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1)
) AS d;

-- INSERT ... EXEC нь хэдэн зуун result set хэвлэгдэхээс сэргийлнэ.
CREATE TABLE #InvoiceSink
(
    InvoiceId     INT, InvoiceNumber NVARCHAR(20), CustomerId INT,
    IssueDate     DATE, DueDate DATE, Status NVARCHAR(15),
    Subtotal      DECIMAL(12,2), TaxAmount DECIMAL(12,2), TotalAmount DECIMAL(12,2),
    LineCount     INT
);

DECLARE @RowNo       INT = 1,
        @MaxRowNo    INT = (SELECT ISNULL(MAX(RowNo), 0) FROM #ToInvoice),
        @CustomerId  INT,
        @MonthStart  DATE,
        @MonthEnd    DATE,
        @IssueDate   DATE,
        @NewInvoice  INT,
        @Created     INT = 0;

WHILE @RowNo <= @MaxRowNo
BEGIN
    SELECT @CustomerId = CustomerId,
           @MonthStart = MonthStart,
           @MonthEnd   = MonthEnd
    FROM #ToInvoice
    WHERE RowNo = @RowNo;

    -- Нэхэмжлэх дараагийн сарын 3-нд гарна
    SET @IssueDate = DATEADD(DAY, 2, DATEADD(MONTH, 1, @MonthStart));

    -- TRY/CATCH-гүй: 50042 энд гарахгүй, өөр алдаа гарвал seed зогсох ёстой.
    INSERT INTO #InvoiceSink
    EXEC dbo.usp_GenerateCustomerInvoice
         @CustomerId  = @CustomerId,
         @PeriodStart = @MonthStart,
         @PeriodEnd   = @MonthEnd,
         @IssueDate   = @IssueDate,
         @InvoiceId   = @NewInvoice OUTPUT;

    SET @Created = @Created + 1;

    SET @RowNo = @RowNo + 1;
END

DROP TABLE #ToInvoice;
DROP TABLE #InvoiceSink;
PRINT 'Invoices created via usp_GenerateCustomerInvoice: ' + CAST(@Created AS VARCHAR(10));
GO

-- Төлбөрийг usp_RecordPayment-ээр оруулна, нэхэмжлэхийн төлвийг trigger шинэчилнэ.
-- 4+ сар: бүтэн, 2-4 сар: ихэнх нь бүтэн, 2-оос бага: хэсэгчлэн эсвэл төлөөгүй.

DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

SELECT
    ROW_NUMBER() OVER (ORDER BY i.IssueDate, i.InvoiceId) AS RowNo,
    i.InvoiceId,
    i.IssueDate,
    i.DueDate,
    i.TotalAmount,
    DATEDIFF(MONTH, i.IssueDate, @Today) AS AgeMonths
INTO #ToPay
FROM dbo.Invoices AS i
WHERE i.Status = N'Issued';

CREATE TABLE #PaymentSink
(
    PaymentId INT, InvoiceId INT, AmountPaid DECIMAL(12,2),
    RemainingBalance DECIMAL(12,2), InvoiceStatus NVARCHAR(15),
    CustomerOutstandingBalance DECIMAL(12,2)
);

DECLARE @RowNo    INT = 1,
        @MaxRowNo INT = (SELECT ISNULL(MAX(RowNo), 0) FROM #ToPay),
        @InvoiceId INT,
        @DueDate   DATE,
        @Total     DECIMAL(12,2),
        @AgeMonths INT,
        @Amount    DECIMAL(12,2),
        @PaidOn    DATE,
        @MethodId  INT,
        @PaymentId INT,
        @Posted    INT = 0;

WHILE @RowNo <= @MaxRowNo
BEGIN
    SELECT @InvoiceId = InvoiceId,
           @DueDate   = DueDate,
           @Total     = TotalAmount,
           @AgeMonths = AgeMonths
    FROM #ToPay
    WHERE RowNo = @RowNo;

    -- төлөх дүн
    SET @Amount =
        CASE
            WHEN @AgeMonths >= 4                       THEN @Total
            WHEN @AgeMonths >= 2 AND @InvoiceId % 9 <> 0 THEN @Total
            WHEN @AgeMonths >= 2                       THEN CAST(@Total * 0.45 AS DECIMAL(12,2))
            WHEN @InvoiceId % 3 = 0                    THEN CAST(@Total * 0.60 AS DECIMAL(12,2))
            ELSE 0
        END;

    IF @Amount > 0
    BEGIN
        -- төлөх хугацааны ойролцоо төлөгдөнө
        SET @PaidOn = DATEADD(DAY, (@InvoiceId % 17) - 5, @DueDate);
        IF @PaidOn > @Today SET @PaidOn = @Today;

        SET @MethodId = CASE (@InvoiceId % 4) WHEN 0 THEN 2 WHEN 1 THEN 1 WHEN 2 THEN 3 ELSE 1 END;

        INSERT INTO #PaymentSink
        EXEC dbo.usp_RecordPayment
             @InvoiceId       = @InvoiceId,
             @PaymentMethodId = @MethodId,
             @Amount          = @Amount,
             @ReferenceNumber = N'BANK-REF-',
             @PaidOn          = @PaidOn,
             @ReceivedBy      = 13,
             @PaymentId       = @PaymentId OUTPUT;

        -- төлбөр бүрт давхцахгүй reference дугаар
        UPDATE dbo.Payments
        SET ReferenceNumber = N'BANK-REF-' + RIGHT(N'000000' + CAST(@PaymentId AS NVARCHAR(10)), 6)
        WHERE PaymentId = @PaymentId;

        SET @Posted = @Posted + 1;
    END

    SET @RowNo = @RowNo + 1;
END

DROP TABLE #ToPay;
DROP TABLE #PaymentSink;
PRINT 'Payments posted via usp_RecordPayment: ' + CAST(@Posted AS VARCHAR(10));
GO

-- Хугацаа хэтэрсэн, төлөгдөөгүй нэхэмжлэх -> Overdue
UPDATE dbo.Invoices
SET Status    = N'Overdue',
    UpdatedAt = SYSUTCDATETIME()
WHERE Status = N'Issued'
  AND DueDate < CAST(SYSUTCDATETIME() AS DATE);
GO

/* Жишээ датаны тойм */
SELECT 'Countries'             AS TableName, COUNT(*) AS Rows FROM dbo.Countries
UNION ALL SELECT 'Cities',                COUNT(*) FROM dbo.Cities
UNION ALL SELECT 'Addresses',             COUNT(*) FROM dbo.Addresses
UNION ALL SELECT 'Customers',             COUNT(*) FROM dbo.Customers
UNION ALL SELECT 'CustomerContacts',      COUNT(*) FROM dbo.CustomerContacts
UNION ALL SELECT 'Terminals',             COUNT(*) FROM dbo.Terminals
UNION ALL SELECT 'Employees',             COUNT(*) FROM dbo.Employees
UNION ALL SELECT 'Drivers',               COUNT(*) FROM dbo.Drivers
UNION ALL SELECT 'VehicleTypes',          COUNT(*) FROM dbo.VehicleTypes
UNION ALL SELECT 'Vehicles',              COUNT(*) FROM dbo.Vehicles
UNION ALL SELECT 'MaintenanceRecords',    COUNT(*) FROM dbo.MaintenanceRecords
UNION ALL SELECT 'ServiceLevels',         COUNT(*) FROM dbo.ServiceLevels
UNION ALL SELECT 'CargoCategories',       COUNT(*) FROM dbo.CargoCategories
UNION ALL SELECT 'Lanes',                 COUNT(*) FROM dbo.Lanes
UNION ALL SELECT 'LaneRates',             COUNT(*) FROM dbo.LaneRates
UNION ALL SELECT 'Shipments',             COUNT(*) FROM dbo.Shipments
UNION ALL SELECT 'ShipmentItems',         COUNT(*) FROM dbo.ShipmentItems
UNION ALL SELECT 'ShipmentStatusHistory', COUNT(*) FROM dbo.ShipmentStatusHistory
UNION ALL SELECT 'Trips',                 COUNT(*) FROM dbo.Trips
UNION ALL SELECT 'TripDrivers',           COUNT(*) FROM dbo.TripDrivers
UNION ALL SELECT 'TripShipments',         COUNT(*) FROM dbo.TripShipments
UNION ALL SELECT 'Invoices',              COUNT(*) FROM dbo.Invoices
UNION ALL SELECT 'InvoiceLines',          COUNT(*) FROM dbo.InvoiceLines
UNION ALL SELECT 'PaymentMethods',        COUNT(*) FROM dbo.PaymentMethods
UNION ALL SELECT 'Payments',              COUNT(*) FROM dbo.Payments
ORDER BY TableName;
GO
