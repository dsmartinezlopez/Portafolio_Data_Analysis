### Proyecto product reviews Amazon

Paso 1: Vista general de las tablas 

```bash
SELECT * FROM Reviews

SELECT * FROM Products
```
Paso 2: Revisión de esquema de tablas y tipos de datos

```bash

SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES

SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Reviews'

SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Products'
```
Paso 3: Revisión del tamaño de las tablas y cantidad de registros por tabla

```bash
EXEC sp_MSforeachtable 'EXEC sp_spaceused [?]';
```

Paso 4: Revisión de los registros duplicados y valores nulos para la conexión de llaves entre tablas 

```bash
SELECT 
	productASIN, 
	COUNT(*) AS veces_repetidas
FROM Reviews
GROUP BY productASIN
HAVING COUNT(*) > 1
ORDER BY veces_repetidas DESC
-- Resultado: Existen valores repetidos. Esto porque pueden haber varias revisiones para un mismo producto

SELECT * FROM Reviews
WHERE productASIN IS NULL

-- Resultado: No hay valores nulos para los ID de los productos

--------------------------------------------------------------------------------
SELECT 
	ID_producto, 
	COUNT(*) AS duplicados
FROM Products
GROUP BY ID_producto
HAVING COUNT(*) > 1

-- Resultado: No hay valores duplicados para cada producto. Esto quiere decir que la conexión entre tablas queda:
-- Products 1------* Reviews

SELECT * FROM Products
WHERE ID_producto IS NULL

-- Resultado: No hay valores nulos para los ID de productos
```

