
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
	asin, 
	COUNT(*) AS duplicados
FROM Products
GROUP BY asin
HAVING COUNT(*) > 1

-- Resultado: No hay valores duplicados para cada producto. Esto quiere decir que la conexión entre tablas queda:
-- Products 1------* Reviews

SELECT * FROM Products
WHERE asin IS NULL

-- Resultado: No hay valores nulos para los ID de productos

-- Paso 5: Relaciones entre tablas
SELECT 
*
FROM Products A
LEFT JOIN Reviews B
ON A.asin = B.productASIN

--Exploración 

--Preguntas:
--1. ¿Cuales fueron los meses que más se revisaron productos para cada uno de los países y cual fue el promedio del sentiment_score en esos meses para cada producto?

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


--2. ¿Cuales fueron el top 5 de marcas que más recibieron 5 estrellas por la distribución de sus productos y qué productos fueron esos?
--3. ¿Cuál fue el producto con más reviews pero que peor sentiment_score tuvo y en qué ranking de productos está?



