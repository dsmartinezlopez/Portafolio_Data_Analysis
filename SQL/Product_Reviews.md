## Proyecto product reviews Amazon

Esta es una explicación de paso por paso en MS SQL Server para el desarrollo de este proyecto.

Código completo: [Product_Reviews](https://github.com/dsmartinezlopez/Portafolio_Data_Analysis/blob/Portafolio-projects-1/Products_review.sql)

> [!NOTE]
> Si tienes instalado en tu PC MS SQL Server puedes copiar y pegar todo el código completo. Sin embargo, para efectos de organización a continuación se muestra el paso a paso de lo que se realizó.

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
Paso 5: Relaciones entre tablas

```bash
SELECT 
*
FROM Products A
LEFT JOIN Reviews B
ON A.ID_producto = B.productASIN
```
## Etapa de exploración - preguntas de negocio

#### 1. ¿Cuales fueron los meses que más se revisaron productos para cada uno de los países y cual fue el promedio del sentiment_score en esos meses para cada producto?

```bash
 WITH cte_1 AS(
	SELECT 
		CountryReview,
		MonthReview,
		productASIN,
		COUNT(reviewID) AS conteo_reviews_productos,
		AVG(COALESCE(TRY_CAST(sentiment_score AS decimal(30,2)),0)) AS sentiment_score
	FROM Reviews
	GROUP BY CountryReview, MonthReview, productASIN
	HAVING COUNT(reviewID) >= 1
),
cte_2 AS(	
	SELECT
		*,
		ROW_NUMBER() OVER(PARTITION BY CountryReview,MonthReview ORDER BY SUM(conteo_reviews_productos) DESC) AS top_productos_del_mes
	FROM cte_1
	GROUP BY CountryReview,MonthReview,productASIN,conteo_reviews_productos,sentiment_score
),
cte_3 AS(	
	SELECT 
		CountryReview,
		MonthReview,
		productASIN,
		conteo_reviews_productos,
		sentiment_score
	FROM cte_2
	WHERE 1=1
	AND top_productos_del_mes = 1
)
SELECT * FROM cte_3
EXCEPT
SELECT * FROM cte_3
WHERE 1=1
AND CountryReview = 'No information record'
GROUP BY CountryReview,MonthReview,productASIN,conteo_reviews_productos,sentiment_score
;
```

#### Resultado

```bash
/*-----------------------+-------------+-------------+--------------------------+------------------+
 | CountryReview         | MonthReview| productASIN | conteo_reviews_productos | sentiment_score  |
 +-----------------------+-------------+-------------+--------------------------+------------------+
 | Belgium               | November   | B0BZ92J5MM  | 1                        | 0.000000         |
 | Canada                | February   | B09CVB14HY  | 1                        | 0.300000         |
 | Germany               | February   | B0BN39ZRYD  | 1                        | 0.000000         |
 | Germany               | November   | B0D8GYHB4M  | 1                        | 0.000000         |
 | Germany               | September  | B08DD9LQ9S  | 1                        | -0.420000        |
 | India                 | April      | B01C7KBKJU  | 1                        | 0.750000         |
 | India                 | August     | B08M429KCV  | 2                        | 0.165000         |
 | India                 | December   | B01C7KBKJU  | 3                        | 0.103333         |
 | India                 | February   | B0D3XM6H68  | 6                        | 0.538333         |
 | India                 | January    | B0BRVDXXYV  | 4                        | 0.475000         |
 | India                 | July       | B0CTZZP8LN  | 2                        | 0.250000         |
 | India                 | June       | B0B38Y9436  | 2                        | 0.395000         |
 | India                 | March      | B01C7KBKJU  | 2                        | 0.490000         |
 | India                 | May        | B0CQG4FZ5M  | 2                        | 0.625000         |
 | India                 | November   | B07VCLR2ZS  | 3                        | 0.216666         |
 | India                 | October    | B0D79795VN  | 4                        | 0.312500         |
 | India                 | September  | B0B4FWZB49  | 2                        | 0.180000         |
 | Mexico                | January    | B0BZ92J5MM  | 1                        | 0.000000         |
 | Mexico                | June       | B0BZ92J5MM  | 2                        | 0.025000         |
 | United Arab Emirates  | August     | B08DD9LQ9S  | 1                        | -0.150000        |
 | United Arab Emirates  | March      | B0C2DFMQ3V  | 1                        | 0.700000         |
 | United Arab Emirates  | October    | B08M429KCV  | 1                        | 0.000000         |
 | United Kingdom        | August     | B0BN39ZRYD  | 1                        | 0.000000         |
 | United Kingdom        | December   | B0BN39ZRYD  | 1                        | 0.600000         |
 | United Kingdom        | February   | B0BNF2F5QZ  | 1                        | 0.550000         |
 | United Kingdom        | November   | B0C8MYJMTG  | 1                        | 0.700000         |
 | United Kingdom        | October    | B0BC3PS8XJ  | 1                        | 0.520000         |
 | United States         | April      | B077SVB38N  | 3                        | 0.146666         |
 | United States         | August     | B07SN9RS13  | 3                        | 0.186666         |
 | United States         | December   | B0C24NCRHX  | 6                        | 0.371666         |
 | United States         | February   | B0B883C9XX  | 9                        | 0.264444         |
 | United States         | January    | B0874WPYV6  | 7                        | 0.480000         |
 | United States         | July       | B01BDZMRR4  | 5                        | 0.230000         |
 | United States         | June       | B09Q618MMY  | 4                        | 0.312500         |
 | United States         | March      | B0DRJ7HB8Y  | 10                       | 0.253000         |
 | United States         | May        | B071GB2K21  | 3                        | 0.133333         |
 | United States         | November   | B0BC3PS8XJ  | 4                        | 0.750000         |
 | United States         | October    | B07FMZ31SR  | 3                        | 0.130000         |
 | United States         | September  | B074KL8RVS  | 3                        | 0.270000         |
 +-----------------------+-------------+-------------+--------------------------+------------------+*/
```


#### 2. ¿Cuales fueron el top 5 de marcas que más recibieron 5 estrellas por la distribución de sus productos y que tuvieron más de 1000 encuestas por ese producto y qué productos fueron esos?

```bash
EXEC sp_rename 'Products.5rating_distribution', 'rating_distribution', 'COLUMN';
EXEC sp_rename 'Products.asin', 'ID_producto', 'COLUMN';

SELECT 
	TOP 5 *
FROM(
	SELECT
		brand_name,
		ID_producto AS productos,
		rating_count * 1000 AS Cantidad_encuestas,
		product_url AS Link,
		FORMAT(AVG(COALESCE(TRY_CAST(rating_distribution AS decimal(20,3)),0)),'P0') AS distribución,
		DENSE_RANK() OVER(PARTITION BY brand_name ORDER BY rating_distribution ASC) AS ranking_marca
	FROM Products
	GROUP BY brand_name,ID_producto,product_url,rating_count,rating_distribution
) AS consulta
WHERE 1=1
AND ranking_marca = 1
AND Cantidad_encuestas > 1000
ORDER BY distribución DESC
```

#### Resultado

```bash

```

#### 3. ¿Cuáles fueron los productos y las subcategorias con más reviews pero que peor sentiment_score tuvieron y en qué ranking de productos estuvieron?

```bash
EXEC sp_rename 'Products.Level 2 - Category', 'Subcategoria', 'COLUMN';

WITH cte_ranking AS(
	SELECT 
		productASIN,
		contador_reviews,
		AVG(promedio_score) AS sentiment_score
	FROM 
		(SELECT
			productASIN,
			COUNT(*) OVER(PARTITION BY(productASIN)) AS contador_reviews,
			AVG(COALESCE(TRY_CAST(sentiment_score AS decimal(20,5)),0)) OVER(PARTITION BY(reviewID))  AS promedio_score
		FROM Reviews
		GROUP BY productASIN,sentiment_score,reviewID
		HAVING COUNT(*) >= 1
		) AS Subconsulta
	GROUP BY productASIN,contador_reviews
)
SELECT
	A.*,
	B.Subcategoria,
	COALESCE(TRY_CAST(B.product_ranking AS INT),0) AS ranking_producto
FROM cte_ranking A
INNER JOIN Products B
ON A.productASIN = B.ID_producto
WHERE 1=1
AND B.Subcategoria IS NOT NULL
ORDER BY contador_reviews DESC
```
#### 4. ¿Cuándo fue el último review de un producto y cuantos días han pasado desde la fecha a la actualidad?
```bash
CREATE VIEW fecha_formateada 
AS
SELECT
	productASIN,
	reviewID,
	YearReview,
	MonthReview,
	DayReview
FROM Reviews

ALTER VIEW fecha_formateada
AS
SELECT
	productASIN,
	reviewID,
	FORMAT(TRY_CAST(fecha AS date), 'dd-MMM-yyyy') AS fecha_review
FROM(
	SELECT
		productASIN,
		reviewID,
		CONCAT(DayReview,'/',MonthReview,'/',YearReview) AS fecha
	FROM Reviews
) AS formato

-- fecha review último producto y días de diferencia a hoy

SELECT
	último_review,
	hoy,
	DATEDIFF(DAY,último_review,hoy) AS días_de_diferencia
FROM(
	SELECT 
		MAX(CONVERT(DATE, fecha_review, 106)) AS último_review,
		CONVERT(DATE, GETDATE(), 106) AS hoy
	FROM fecha_formateada
	WHERE 1=1 
	AND fecha_review IS NOT NULL
) AS fechas
```
#### 5. ¿Cuántas reviews por día de la semana de cada mes y año tuvo el producto que más se comercializó en EE.UU?
```bash
SET DATEFIRST 7

SELECT 
	ID_producto,
	product_url,
	rating_count AS multiplicador
FROM Products
ORDER BY multiplicador DESC

--El producto que tuvo más calificaciones por parte de los clientes fue el B0B1WMKNM5


WITH cte_fechas AS(
	SELECT 
		reviewID,
		YearReview,
		MonthReview,
		CASE
			WHEN día_semana = 1 THEN 'Domingo'
			WHEN día_semana = 2 THEN 'Lunes'
			WHEN día_semana = 3 THEN 'Martes'
			WHEN día_semana = 4 THEN 'Miércoles'
			WHEN día_semana = 5 THEN 'Jueves'
			WHEN día_semana = 6 THEN 'Viernes'
			WHEN día_semana = 7 THEN 'Sábado'
		END AS día
	FROM(
		SELECT
			productASIN,
			reviewID,
			YearReview,
			MonthReview,
			DATEPART(WEEKDAY,fecha_review) AS día_semana
		FROM fecha_formateada
		WHERE 1=1
		AND CountryReview = 'United States'
		AND productASIN = 'B0B1WMKNM5'
	) AS sub_1
)
SELECT
	*
FROM cte_fechas
PIVOT
(
	COUNT(reviewID)
	FOR	día IN([Lunes],[Martes],[Miércoles],[Jueves],[Viernes],[Sábado],[Domingo])
) AS pvt 

ORDER BY YearReview ASC
```
