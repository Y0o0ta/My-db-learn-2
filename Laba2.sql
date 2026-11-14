----Шаг 1 сверка
----В прошлой лабе я случайно прогнала запрос в FactSales дважды
----поэтому при проверке таблиц обнаружила не сходство, здесь я это исправляю!!!
use TechStore_DWN;
delete from dbo.FactSales;
---- Проверка:
select count(*) from dbo.FactSales;

----исправление:
use TechStore_DWN;
go
insert into dbo.FactSales (OrderID, DateKey, CustomerKey, ProductKey, Quantity, Price, Amount)
select o.OrderID, dd.DateKey, dc.CustomerKey, dp.ProductKey, oi.Quantity, oi.Price,
cast(oi.Quantity * oi.Price as decimal(12,2)) as Amount
from TechStore.dbo.OrderItems as oi
join TechStore.dbo.Orders as o on o.OrderID=oi.OrderID
join dbo.DimCustomer as dc on dc.CustomerID=o.CustomerID
join dbo.DimProduct as dp on dp.ProductID=oi.ProductID
join dbo.DimDate as dd on dd.DateKey= cast(convert(char(8), o.OrderDate, 112) as int);
go
----теперь FactSales 43 строки и TotalUnits 1914000.00

--Шаг 3
use TechStore;
go
create schema stg;
go
create table stg.CustomersImportRaw (
CustomerID nvarchar(50),
FirstName nvarchar(100),
LastName nvarchar(100),
Email nvarchar(200),
City nvarchar(100)
);

create table stg.ProductsImportRaw (
ProductID nvarchar(50),
ProductName nvarchar(100),
Category nvarchar(100),
Price nvarchar(100),
);

create table stg.OrdersImportRaw(
OrderID nvarchar(50),
CustomerID nvarchar(50),
OrderDate nvarchar(50)
);

create table stg.OrderItemsImportRaw(
OrderItemID nvarchar(50),
OrderID nvarchar(50),
ProductID nvarchar(50),
Quantity nvarchar(50),
Price nvarchar(50)
);

----Шаг4
----создала папку в диске и поместила туда все csv файлы
----Products
USE TechStore;
GO
BULK INSERT stg.ProductsImportRaw
FROM 'C:\TechStoreImport\02_Products_import.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001'
);
GO
SELECT *
FROM stg.ProductsImportRaw;
GO

----Customers
USE TechStore;
GO
BULK INSERT stg.CustomersImportRaw
FROM 'C:\TechStoreImport\01_Customers_import.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001'
);
GO
SELECT *
FROM stg.CustomersImportRaw;
GO

----Orders
USE TechStore;
GO
BULK INSERT stg.OrdersImportRaw
FROM 'C:\TechStoreImport\03_Orders_import.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001'
);
GO
SELECT *
FROM stg.OrdersImportRaw;
GO

----OrderItems
USE TechStore;
GO
BULK INSERT stg.OrderItemsImportRaw
FROM 'C:\TechStoreImport\04_OrderItems_import.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001'
);
GO
SELECT *
FROM stg.OrderItemsImportRaw;
GO

----Шаг6
----Customers
use TechStore;
go
select 
try_convert(int, trim(CustomerID)) as CustomerID,
trim(FirstName) as FirstName,
trim(LastName)as LastName,
nullif(TRIM(Email), '')as Email,
trim(City)as City
from stg.CustomersImportRaw;

----Products
use TechStore;
go
select
try_convert(int, trim(ProductID))as ProductID,
trim(ProductName)as ProductName,
trim(Category)as Category,
try_convert(decimal(12,2),
replace(replace(replace(trim(Price), ' ', ''), '₽', ''), ',', '.'))as Price
from stg.ProductsImportRaw;

----Orders
use TechStore;
go
select
try_convert(int, trim(OrderID))as OrderID,
try_convert (int, trim(CustomerID))as CustomerID,
try_convert (date, trim(OrderDate), 104) as OrderDate   
from stg.OrdersImportRaw;

----OrderItems
use TechStore;
go
select
try_convert(int, trim(OrderItemID)) as OrderItemID,
try_convert (int, trim(OrderID))as OrderID,
try_convert(int, trim(ProductID))as ProductID,
try_convert(int, trim(Quantity))as Quantity,
try_convert(decimal(12,2),
replace(replace(replace(trim(Price), ' ', ''), '₽', ''), ',', '.'))as Price
from stg.OrderItemsImportRaw;

----Шаг7 Проверка Validation 
----Customers
use TechStore;
go
select*from stg.CustomersImportRaw
where try_convert(int, trim(CustomerID))is null
or trim(FirstName)= '' or trim(LastName) = '';

---- Products
use TechStore;
go
select * from stg.ProductsImportRaw
where try_convert(int, trim(ProductID)) is null
or trim(ProductName)= ''
or try_convert(decimal(12,2),
replace(replace(replace(trim(Price), ' ', ''), '₽', ''), ',', '.')) is null
or try_convert(decimal(12,2),
replace(replace(replace(trim(Price), ' ', ''), '₽', ''), ',', '.'))<0;

---- Orders
use TechStore;
go
select * from stg.OrdersImportRaw
where try_convert(int, trim(OrderID))is null
or try_convert(int, trim(CustomerID))is null
or try_convert(date, trim(OrderDate), 104)is null;

---- OrderItems
use TechStore;
go
select * from stg.OrderItemsImportRaw
where try_convert(int, trim(OrderItemID))is null
or try_convert(int, trim(OrderID))is null
or try_convert(int, trim(ProductID))is null
or try_convert(int, trim(Quantity))is null
or try_convert(int, trim(Quantity))<=0
or try_convert(decimal(12,2),
replace(replace(replace(trim(Price), ' ', ''), '₽', ''), ',', '.'))is null;

----здесь я пытаюсь исправить все косяки 
-- Причины в Products
use TechStore;
go
select ProductID, ProductName, Category, Price,
case when try_convert(int, trim(ProductID))is null then 'error' end as error_id,
case when trim(ProductName) = '' then 'error' end as error_name,
case when try_convert(decimal(12,2), Price) is null
then 'error' end as error_price,
case when try_convert(decimal(12,2), Price)<0
then 'error' end as error_neg
from stg.ProductsImportRaw
where try_convert(int, trim(ProductID))is null
or trim(ProductName) =''
or try_convert(decimal(12,2), Price)is null
or try_convert(decimal(12,2), Price)<0;

----Поиск нежелательных пробелов
use TechStore;
go
select ProductID, Price,
len(Price) as len,
charindex(nchar(160), Price)as pos_nbsp,-- неразрывный пробел
charindex(nchar(8239), Price)as pos_nnbsp,-- узкий неразрывный пробел
charindex('₽', Price)as pos_rub,
charindex(',', Price)as pos_comma,
charindex('.', Price)as pos_dot
from stg.ProductsImportRaw
where try_convert(decimal(12,2),
replace(replace(replace(trim(Price), ' ', ''), '₽', ''), ',', '.'))is null;

----Исправление через update
use TechStore;
go
update stg.ProductsImportRaw
set Price = replace(replace(replace(replace(Price, nchar(160), ''),-- неразрывный пробел
' ', ''),-- обычный пробел
'₽', ''),',', '.')
where try_convert(decimal(12,2),
replace(replace(replace(Price, nchar(160), ''), ' ', ''), '₽', ''))is null
or charindex(nchar(160), Price)>0;

use TechStore;
go

----опять убираю невидимые символы
update stg.ProductsImportRaw
set Price = replace(replace(Price, char(13), ''), char(10), '')
where charindex(char(13), Price) > 0 or charindex(char(10), Price)>0;
go
----уберу знак рубля он все ломает
update stg.ProductsImportRaw set Price = left(Price, len(Price) - 1);


----в чем проблема в orders
use TechStore;
go

with src as (
select OrderID,CustomerID,OrderDate,
try_convert(int, trim(OrderID))as id_num,
try_convert(int, trim(CustomerID))as cust_num,
try_convert(date, trim(OrderDate), 104) as date_num
from stg.OrdersImportRaw
)
select *,
case when id_num is null then 'error'end as error_id,
case when cust_num is null then 'error' end as error_cust,
case when date_num is null then 'error'end as error_date
from src
where id_num is null
or cust_num is null
or date_num is null;


----Поиск лишних символов
use TechStore;
go
select OrderID, OrderDate,
len(OrderDate) as len, 
charindex('.', OrderDate)as pos_dot1,
charindex('.', OrderDate, 4)as pos_dot2,
charindex(nchar(160), OrderDate)as pos_nbsp, --неразрывный пробел
charindex(' ', OrderDate)as pos_space,-- обычный пробел
unicode(substring(OrderDate, len(OrderDate), 1)) as last_char
from stg.OrdersImportRaw;

use TechStore;
go
select OrderID, OrderDate,
len(OrderDate)as len,
unicode(substring(OrderDate, 11, 1))as code_11,  -- 11-й символ
unicode(substring(OrderDate, 10, 1))as code_10, -- 10-й (должен быть цифрой)
ascii(RIGHT(OrderDate, 1)) as ascii_last
from stg.OrdersImportRaw where len(OrderDate) = 11;

----Испрпавление через update
use TechStore;
go
update stg.OrdersImportRaw
set OrderDate = replace(replace(replace(trim(OrderDate), char(13), ''), char(10), ''), nchar(160), '')
where charindex(char(13), OrderDate)> 0
or charindex(char(10), OrderDate)>0
or charindex(nchar(160), OrderDate) >0
or len(OrderDate) <>10;

----OrderItems
use TechStore;
go

with src as (
select OrderItemID,OrderID,ProductID,Quantity,Price,
try_convert(int, trim(OrderItemID))as item_id_num,
try_convert(int, trim(OrderID))as order_id_num,
try_convert(int, trim(ProductID))as product_id_num,
try_convert(int, trim(Quantity))as qty_num,
try_convert(decimal(12,2),
replace(replace(replace(replace(trim(price), nchar(160), ''), char(13), ''), char(10), ''), ',', '.'))                                     AS price_num,
len(OrderItemID) as len_item,
len(OrderID)as len_order,
len(ProductID) as len_product,
len(Quantity)as len_qty,
len(Price)as len_price
from stg.OrderItemsImportRaw
)
select *,
case when item_id_num is null then 'error' end as error_item_id,
case when order_id_num is null then 'error' end as error_order_id,
case when product_id_num is null then 'error' end as error_product_id,
case when qty_num is null then 'error' end as error_qty_null,
case when qty_num <= 0 then 'error' end as error_qty_zero,
case when price_num is null then 'error' end as error_price
from src
where item_id_num is null
or order_id_num is null
or product_id_num is null
or qty_num is null
or qty_num<= 0
or price_num is null;

----проблема в Price
----что тут не так
use TechStore;
go

select OrderItemID, Price,
len(Price) as len,
charindex(char(13), Price)as pos_cr,-- \r
charindex(char(10), Price)as pos_lf,-- \n
charindex(nchar(160), Price)as pos_nbsp,-- неразрывный пробел
charindex(' ', Price)as pos_space,-- обычный пробел
charindex('₽', Price)as pos_rub,
charindex(',', Price)as pos_comma,
charindex('.', Price)as pos_dot,
unicode(substring(Price, 1, 1))as first_char,
unicode(substring(Price, len(Price), 1)) as last_char
from stg.OrderItemsImportRaw
where try_convert(decimal(12,2),
replace(replace(replace(replace(trim(Price), nchar(160), ''), char(13), ''), char(10), ''), ',', '.'))is null;


----исправление 
use TechStore;
go

update stg.OrderItemsImportRaw set Price = replace(Price, char(13), '');
go
update stg.OrderItemsImportRaw set Price = replace(Price, CHAR(10), '');
go
update stg.OrderItemsImportRaw set Price = replace(Price, NCHAR(160), '');
go
update stg.OrderItemsImportRaw set Price = replace(Price, NCHAR(8239), '');
go
update stg.OrderItemsImportRaw set Price = replace(Price, NCHAR(65279), '');
go
update stg.OrderItemsImportRaw set Price = replace(Price, NCHAR(8381), '');
go
update stg.OrderItemsImportRaw set Price = replace(Price, ' ', '');
go
update stg.OrderItemsImportRaw set Price = replace(Price, ',', '.');
go


use TechStore;
go
update stg.OrderItemsImportRaw
set Price = replace(Price, nchar(8381), '');

use TechStore;
go
select top 5 OrderItemID, Price, 
len(Price) as len,
unicode(substring(Price, len(Price), 1)) as new_last_char,
try_convert(decimal(12,2), Price) as price_num
from stg.OrderItemsImportRaw;

----я ничего не придумала лучше чем отрезать этот знак рубля потому что он ломает кодировку
use TechStore;
update stg.OrderItemsImportRaw set Price = left(Price, len(Price) - 1);

----всё, все таблицы проходят validation 

----Шаг8
----Загрузка Customers
USE TechStore;
GO
SET IDENTITY_INSERT dbo.Customers ON;

    INSERT INTO dbo.Customers (CustomerID, FirstName, LastName, Email, City)
    SELECT 
        TRY_CONVERT(INT, TRIM(CustomerID)),
        TRIM(FirstName),
        TRIM(LastName),
        NULLIF(TRIM(Email), ''),
        TRIM(City)
    FROM stg.CustomersImportRaw s
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Customers c 
        WHERE c.CustomerID = TRY_CONVERT(INT, TRIM(s.CustomerID))
    );

    SET IDENTITY_INSERT dbo.Customers OFF;

----Загрузка Products
----из за того что таблицы Identity придется выключать/включать(on/off) их что бы вставить другие id
use TechStore;
go
set identity_insert dbo.Products on;
insert into dbo.Products (ProductID, ProductName, Category, Price)
select
try_convert(int, trim(ProductID)),
trim(ProductName),
trim(Category),
try_convert(decimal(12,2), Price) ---- Цена уже почищена
from stg.ProductsImportRaw s
where not exists (
select 1 from dbo.Products p 
where p.ProductID = try_convert(int, trim(s.ProductID))
);
set identity_insert dbo.Products off;

----Загрузка orders
use TechStore;
go
set identity_insert dbo.Orders on;

insert into dbo.Orders (OrderID, CustomerID, OrderDate)
select
try_convert(int, trim(OrderID)),
try_convert(int, trim(CustomerID)),
try_convert(date, trim(OrderDate), 104) 
from stg.OrdersImportRaw s
where not exists (
select 1 from dbo.Orders o 
where o.OrderID = try_convert(int, trim(s.OrderID))
);
set identity_insert dbo.Orders off;

----Загрузка OrderItems
use TechStore;
go
set identity_insert dbo.OrderItems on;

insert into dbo.OrderItems (OrderItemID, OrderID, ProductID, Quantity, Price)
select
try_convert(int, trim(OrderItemID)),
try_convert(int, trim(OrderID)),
try_convert(int, trim(ProductID)),
try_convert(int, trim(Quantity)),
try_convert(decimal(12,2), Price)
from stg.OrderItemsImportRaw s
where not exists (
select 1 from dbo.OrderItems i 
where i.OrderItemID =try_convert(int, trim(s.OrderItemID))
);
set identity_insert dbo.OrderItems off;


----Шаг 9 проверка записей 
use TechStore;
go

select 'Customers'  as tbl, count(*) as cnt from dbo.Customers   
union all select'Products',count(*) from dbo.Products          
union all select 'Orders', count(*) from dbo.Orders            
union all select 'OrderItems',count(*) from dbo.OrderItems;
---- Проверка суммы
select sum(Quantity) as TotalUnits, 
sum(Quantity * Price) as TotalRevenue 
from dbo.OrderItems;


----Шаг 10 Удаление 
USE TechStore_DWN;
GO

DELETE FROM dbo.FactSales;
DELETE FROM dbo.DimDate;
DELETE FROM dbo.DimProduct;
DELETE FROM dbo.DimCustomer;

DBCC CHECKIDENT ('dbo.FactSales', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimProduct', RESEED, 0);
DBCC CHECKIDENT ('dbo.DimCustomer', RESEED, 0);
GO

----Шаг11 Аналитика 
USE TechStore;
GO

SELECT 'Customers' AS TableName, COUNT(*) AS [RowCount] FROM dbo.Customers
UNION ALL SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL SELECT 'Orders', COUNT(*) FROM dbo.Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems;

SELECT
    SUM(Quantity) AS TotalUnits,
    SUM(CAST(Quantity AS DECIMAL(18,2)) * Price) AS TotalRevenue
FROM dbo.OrderItems;
GO

USE TechStore_DWN;
GO

SELECT 'DimCustomer' AS TableName, COUNT(*) AS [RowCount] FROM dbo.DimCustomer
UNION ALL SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimDate', COUNT(*) FROM dbo.DimDate
UNION ALL SELECT 'FactSales', COUNT(*) FROM dbo.FactSales;

SELECT
    SUM(Quantity) AS TotalUnits,
    SUM(Amount) AS TotalRevenue
FROM dbo.FactSales;

SELECT
    COUNT(*) AS ImportedFactRows,
    SUM(Quantity) AS ImportedUnits,
    SUM(Amount) AS ImportedRevenue
FROM dbo.FactSales
WHERE OrderID BETWEEN 1021 AND 1025;
GO