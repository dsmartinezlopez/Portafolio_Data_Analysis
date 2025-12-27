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
```

