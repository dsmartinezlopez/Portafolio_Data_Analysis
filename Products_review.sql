
USE AmazonEcommerce
GO

--Paso 1: Vista general de las tablas 

SELECT * FROM Reviews

SELECT * FROM Products

--Paso 2: Revisión de esquema de tablas y tipos de datos

SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES

SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Reviews'

SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Products'

-- Paso 3: Revisión del tamaño de las tablas y cantidad de registros por tabla

EXEC sp_MSforeachtable 'EXEC sp_spaceused [?]';

-- Paso 4: Revisión de los registros duplicados y valores nulos para la conexión de llaves entre tablas 

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

-- Paso 5: Relaciones entre tablas
SELECT 
*
FROM Products A
LEFT JOIN Reviews B
ON A.ID_producto = B.productASIN

--Exploración 

--Preguntas:
--1. ¿Cuales fueron los meses que más se revisaron productos para cada uno de los países y cual fue el promedio 
--del sentiment_score en esos meses para cada producto?

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


--2. ¿Cuales fueron el top 5 de marcas que más recibieron 5 estrellas por la distribución de sus productos y que 
--tuvieron más de 1000 encuestas por ese producto y qué productos fueron esos?

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


--3. ¿Cuáles fueron los productos y las subcategorias con más reviews pero que peor sentiment_score tuvieron y en qué ranking de productos estuvieron?

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

--4. ¿Cuándo fue el último review de un producto y cuantos días han pasado desde la fecha a la actualidad?

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

--5. ¿Cuántas reviews por día de la semana de cada mes y año tuvo el producto que más se comercializó en EE.UU?

