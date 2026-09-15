/*
  NordFreight Logistics  --  01 - Датабааз нээсэн хэсэг
  NordFreight нэртэй датабаз нээж холбогдож байгаа.
*/

USE master;
GO

IF DB_ID(N'NordFreightDB') IS NOT NULL
BEGIN
    PRINT 'Existing NordFreightDB found - dropping it.';
    ALTER DATABASE NordFreightDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE NordFreightDB;
END
GO

CREATE DATABASE NordFreightDB;
GO

-- Жишээ болгож хийж байгаа болохоор лог backup хэрэглэсэнгүй.
ALTER DATABASE NordFreightDB SET RECOVERY SIMPLE;
GO


-- Диспетчер болон төлбөрийн ажиллагаа зэрэгцээд ажиллах үед уншиж байгаа нь санд бичиж байгаагаа хаахгүй байхад анхаарах. 
ALTER DATABASE NordFreightDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

USE NordFreightDB;
GO

PRINT 'NordFreightDB created. Current database: ' + DB_NAME();
GO
