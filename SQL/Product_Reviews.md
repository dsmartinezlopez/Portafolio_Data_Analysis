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
/*-----------------------------+------------+--------------------+--------------------------------------+---------------+---------------+
| brand_name                   | productos  | Cantidad_encuestas | Link                                 | distribución  | ranking_marca |
+------------------------------+------------+--------------------+--------------------------------------+---------------+---------------+
| Burt's Bees Baby Store       | B07M6SSQXH | 21640              | https://www.amazon.com/dp/B07M6SSQXH | 87%           | 1             |
| Little Me Store              | B071HWBZX1 | 8994               | https://www.amazon.com/dp/B071HWBZX1 | 87%           | 1             |
| Brand: Handcraft             | B0D2JCJRFT | 101000             | https://www.amazon.com/dp/B0D2JCJRFT | 86%           | 1             |
| Mioglrie Store               | B08Z755PCH | 4038               | https://www.amazon.com/dp/B08Z755PCH | 86%           | 1             |
| Simple Joys by Carter's Store| B073WMFKPZ | 16170              | https://www.amazon.com/dp/B073WMFKPZ | 86%           | 1             |
+------------------------------+------------+--------------------+--------------------------------------+---------------+---------------+
```

#### 3. ¿Cuáles fueron los productos y las subcategorias con más de 10 reviews pero que peor sentiment_score tuvieron y en qué ranking de productos estuvieron?

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
AND A.contador_reviews > 10
ORDER BY contador_reviews DESC
```

#### Resultado

```bash
/*----------+------------------+----------------+--------------------------------------+--------------------------+
 | productASIN| contador_reviews | sentiment_score| Subcategoria                        | ranking_producto(número) |
 +----------+------------------+----------------+--------------------------------------+--------------------------+
 | B074KL8RVS | 19               | 0.448474       | 13 in Men's Jeans                   | 470                      |
 | B074KL2SHP | 14               | 0.329770       | 13 in Men's Jeans                   | 470                      |
 | B07HR877BN | 14               | 0.213671       | 118 in Men's T-Shirts               | 118                      |
 | B07DRMT92L | 13               | 0.218287       | 3 in Men's Activewear T-Shirts      | 376                      |
 | B08Q86H92W | 13               | 0.350365       | 30 in Men's Flat Front Shorts       | 30                       |
 | B07H12JDN6 | 12               | 0.393430       | 30 in Men's Jeans                   | 30                       |
 | B08GZL48D9 | 12               | 0.280395       | 2 in Men's Boxer Shorts             | 118                      |
 | B00NOY3JKW | 12               | 0.220929       | 1 in Men's T-Shirts                 | 3                        |
 | B016Y8268U | 12               | 0.247250       | 11 in Men's Flat Front Shorts       | 11                       |
 | B07JR4NDKS | 12               | 0.407177       | 94 in Men's T-Shirts                | 94                       |
 | B09Q618MMY | 12               | 0.259638       | 260 in Men's Casual Pants           | 260                      |
 | B09S6VVX5B | 11               | 0.204292       | 5 in Men's T-Shirts                 | 108                      |
 | B09Y8TM3LL | 11               | 0.396995       | 128 in Men's Jeans                  | 128                      |
 | B0B47Q6QYP | 11               | 0.330830       | 284 in Men's Polo Shirts            | 284                      |
 | B0B84WZ5DY | 11               | 0.209910       | 29 in Men's Jeans                   | 29                       |
 | B0BGSDG377 | 11               | 0.347864       | 5 in Men's Activewear Polos         | 5                        |
 | B0BLRWCWCB | 11               | 0.261883       | 6 in Men's Running Shorts           | 6                        |
 | B0BPF1R8KC | 11               | 0.347267       | 11 in Men's T-Shirts                | 114                      |
 | B0BZZSK8TF | 11               | 0.461145       | 23 in Men's Polo Shirts             | 23                       |
 | B0C9C7TKQ7 | 11               | 0.406126       | 857 in Men's Clothing               | 857                      |
 | B0CCT3WHSS | 11               | 0.203296       | 1 in Men's Novelty T-Shirts         | 115                      |
 | B0CJTZLCQ2 | 11               | 0.333776       | 24 in Men's Button-Down Shirts      | 24                       |
 | B0CNXK4KRH | 11               | 0.420128       | 49 in Men's Button-Down Shirts      | 49                       |
 | B0CSWGBR4L | 11               | 0.380424       | 30 in Men's Activewear T-Shirts     | 30                       |
 | B0D9GXG945 | 11               | 0.225320       | 42 in Men's Polo Shirts             | 42                       |
 | B0DMRJYXLP | 11               | 0.405410       | 104 in Men's Athletic Shorts        | 104                      |
 | B0DPZQCX42 | 11               | 0.242407       | 69 in Men's Dress Pants             | 69                       |
 | B07LGQ884Z | 11               | 0.336750       | 1 in Men's Jeans                    | 78                       |
 | B086KKT21F | 11               | 0.299244       | 4 in Men's Undershirts              | 102                      |
 | B086L1PM8V | 11               | 0.297564       | 17 in Men's T-Shirts                | 580                      |
 | B0874W4WQ9 | 11               | 0.297997       | 1 in Men's Compression Shirts       | 373                      |
 | B0874WD2B2 | 11               | 0.375301       | 7 in Men's Activewear T-Shirts      | 662                      |
 | B08BC4HDS2 | 11               | 0.241816       | 10 in Men's Activewear T-Shirts     | 10                       |
 | B08F2P8CS9 | 11               | 0.291768       | 1 in Men's Undershirts              | 10                       |
 | B073372KDR | 11               | 0.413191       | 33 in Men's Jeans                   | 33                       |
 | B00QNAL9U6 | 11               | 0.237614       | 4 in Men's Casual Pants             | 554                      |
 | B00XKYM2AE | 11               | 0.271329       | 6 in Men's Cargo Shorts             | 6                        |
 | B07848QFW3 | 11               | 0.204177       | 39 in Men's Casual Pants            | 39                       |
 | B078LC7GCX | 11               | 0.408584       | 16 in Men's T-Shirts                | 395                      |
 | B07BJKWX4Y | 11               | 0.314369       | 16 in Men's Jeans                   | 229                      |
 | B07BN24BLX | 11               | 0.441690       | 13 in Men's Polo Shirts             | 13                       |
 | B08JM661K7 | 11               | 0.331260       | 3 in Men's Dress Pants              | 926                      |
 | B07JBRGFH4 | 11               | 0.237910       | 2 in Men's T-Shirts                 | 6                        |
 | B002GHC19I | 11               | 0.339767       | 1 in Men's Work Utility & Safety    | 18                       |
 | B08SM3CDLN | 11               | 0.327409       | 2 in Men's Activewear Polos         | 521                      |
 | B098KXZG2Z | 11               | 0.325076       | 85 in Men's Jeans                   | 85                       |
 | B09JYPMWP2 | 11               | 0.340515       | 71 in Men's Jeans                   | 71                       |
 +----------+------------------+----------------+--------------------------------------+--------------------------+*/
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
