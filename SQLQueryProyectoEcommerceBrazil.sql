
USE EcommerceBR
GO

-- Etapa de exploración - preguntas de negocio

-- ANÁLISIS CON VISIÓN OPERATIVA
-- kpi's:

-- FULFILLMENT RATE

--preguntas claves:

--1. ¿Cuál fue el volumen de pedidos enviados y cuántos cumplieron el tiempo de entrega y cuántos no?

WITH cte_1 AS (
	SELECT
		order_id,
		order_status,
		COUNT(*) AS contador_orders,
		order_delivered_customer_date AS fecha_envío_customer
	FROM Orders$
	GROUP BY order_id, order_status, order_delivered_customer_date

),  
cte_2 AS(
	SELECT
		A.order_id AS orden_id,
		contador_orders,
		COALESCE(SUM(CASE WHEN A.fecha_envío_customer > B.shipping_limit_date THEN 1 END)/SUM(CASE WHEN A.fecha_envío_customer > B.shipping_limit_date THEN 1 END),0) AS retardo,
		COALESCE(SUM(CASE WHEN A.fecha_envío_customer <= B.shipping_limit_date THEN 1 END)/SUM(CASE WHEN A.fecha_envío_customer <= B.shipping_limit_date THEN 1 END),0) AS cumplió
	FROM cte_1 A
	INNER JOIN ['Orders items$'] B
	ON A.order_id = B.order_id
	WHERE 1=1
	AND A.order_status = 'delivered'
	AND A.fecha_envío_customer IS NOT NULL 
	GROUP BY A.order_id, contador_orders
),
cte_3 AS(
	SELECT
		orden_id,
		contador_orders,
		retardo,
		cumplió,
		SUM(CASE WHEN retardo = cumplió THEN 1 END) AS pedidos_semiincumplidos
	FROM cte_2
	GROUP BY orden_id, contador_orders, retardo, cumplió
) -- este cte_3 es para diferenciar aquellas órdenes que contenían varios productos donde en alguno de ellos hubo un retardo, por eso se descuentan de los que cumplieron en su totalidad
SELECT 
	COUNT(contador_orders) AS total_pedidos_enviados,
	SUM(cumplió)-SUM(pedidos_semiincumplidos) AS pedidos_que_cumplieron,
	SUM(retardo) AS pedidos_retrasados
FROM cte_3;


--2. ¿Cuál es el GAP de incumplimiento de entregas comparando MoM (Month-over-Month) de cada año?

CREATE VIEW vista_fulfillment_rate AS
WITH cte_1 AS (
	SELECT
		order_id,
		order_status,
		COUNT(*) AS contador_orders,
		order_delivered_customer_date AS fecha_envío_customer
	FROM Orders$
	GROUP BY order_id, order_status, order_delivered_customer_date

),  
cte_2 AS(
	SELECT
		A.order_id AS orden_id,
		contador_orders,
		COALESCE(SUM(CASE WHEN A.fecha_envío_customer > B.shipping_limit_date THEN 1 END)/SUM(CASE WHEN A.fecha_envío_customer > B.shipping_limit_date THEN 1 END),0) AS retardo,
		COALESCE(SUM(CASE WHEN A.fecha_envío_customer <= B.shipping_limit_date THEN 1 END)/SUM(CASE WHEN A.fecha_envío_customer <= B.shipping_limit_date THEN 1 END),0) AS cumplió
	FROM cte_1 A
	INNER JOIN ['Orders items$'] B
	ON A.order_id = B.order_id
	WHERE 1=1
	AND A.order_status = 'delivered'
	AND A.fecha_envío_customer IS NOT NULL 
	GROUP BY A.order_id, contador_orders
),
cte_3 AS(
	SELECT
		orden_id,
		contador_orders,
		retardo,
		cumplió,
		SUM(CASE WHEN retardo = cumplió THEN 1 END) AS pedidos_semiincumplidos
	FROM cte_2
	GROUP BY orden_id, contador_orders, retardo, cumplió
) 
SELECT 
	orden_id,
	COUNT(contador_orders) AS total_pedidos_enviados,
	SUM(cumplió) AS pedidos_que_cumplieron,
	SUM(retardo) AS pedidos_retrasados,
	COALESCE(SUM(pedidos_semiincumplidos),0) AS pedidos_semicumplidos
FROM cte_3
GROUP BY orden_id;



-- respuesta a la consulta de negocio


SELECT 
	año,
	mes,
	pedidos_retrasados,
	FORMAT(ROUND((pedidos_retrasados-v_antes)*1.0/NULLIF(v_antes,0),2), 'P0') AS variación

FROM(

	SELECT 
		año,
		mes_numerico,
		mes,
		pedidos_retrasados,
		LAG(pedidos_retrasados,1,0) OVER(ORDER BY año, mes_numerico) AS v_antes
	
	FROM (
		SELECT 
			YEAR(B.order_purchase_timestamp) AS año,
			MONTH(order_purchase_timestamp) AS mes_numerico,
			FORMAT(B.order_purchase_timestamp,'MMMM') AS mes,
			SUM(A.pedidos_retrasados) AS pedidos_retrasados
		FROM vista_fulfillment_rate A
		LEFT JOIN Orders$ B
		ON A.orden_id = B.order_id
		GROUP BY YEAR(B.order_purchase_timestamp), MONTH(order_purchase_timestamp), FORMAT(B.order_purchase_timestamp,'MMMM'), pedidos_retrasados
		HAVING pedidos_retrasados >= 1
		) AS consulta_1
) AS consulta_2
ORDER BY año, mes_numerico 

--3. Si la clasificación de los productos se establece de acuerdo al peso, donde SMALL se denomina todo lo que pese <= 1000 gramos,
--	 MEDIUM todo lo que pese > 1000 gramos y <= 10000 gramos, y BIG todo lo que pese > 10000 gramos ¿cuales fueron las clasificaciones
--	 que más porcentaje de incumplimiento tuvieron ordenadas de forma descendente?


SELECT
	clasificación,
	SUM(enviados) AS pedidos_enviados,
	SUM(pedidos_retrasados) AS pedidos_retrasados,
	FORMAT(SUM(pedidos_retrasados)*1.0/SUM(enviados)*1.0, 'P2') AS porcentaje
FROM(
SELECT
	CASE 
		WHEN A.product_weight_g <= 1000 THEN 'SMALL'
		WHEN A.product_weight_g > 1000 AND A.product_weight_g <= 10000 THEN 'MEDIUM'
		WHEN A.product_weight_g > 10000 THEN 'BIG'
	END AS clasificación,
	C.total_pedidos_enviados AS enviados,
	C.pedidos_retrasados AS pedidos_retrasados
FROM Products$ A
INNER JOIN ['Orders items$'] B
ON A.product_id = B.product_id
INNER JOIN vista_fulfillment_rate C
ON B.order_id = C.orden_id

) AS subquery
WHERE 1=1
AND clasificación IS NOT NULL
GROUP BY clasificación
ORDER BY porcentaje DESC

--4. ¿Cuál fue el TOP 20 de órdenes_id enviadas que más se demoraron en completarse? muestre id de la orden, producto(s), 
--	 ciudad origen (vendedor), ciudad destino (comprador) y cantidad de días transcurridos desde la fecha de compra y la fecha de entrega. 

CREATE NONCLUSTERED INDEX IDX_order
ON [dbo].['Orders items$'] ([order_id],[seller_id])


CREATE NONCLUSTERED INDEX IDX_seller
ON [dbo].[Sellers$] ([seller_id])


CREATE NONCLUSTERED INDEX IDX_customer
ON [dbo].[Customers$] ([customer_id])


CREATE NONCLUSTERED INDEX IDX_order_delivered
ON [dbo].[Orders$] ([order_status],[order_delivered_customer_date],[order_purchase_timestamp])

SELECT TOP 20 * FROM (
SELECT
	A.orden_id,
	B.product_id,
	C.seller_city AS ciudad_origen,
	E.customer_city AS ciudad_destino,
	D.order_purchase_timestamp AS fecha_compra,
	D.order_delivered_customer_date AS fecha_envío,
	DATEDIFF(DAY,D.order_purchase_timestamp,D.order_delivered_customer_date) AS dias_diferencia
FROM vista_fulfillment_rate A
LEFT JOIN ['Orders items$'] B
ON A.orden_id = B.order_id
LEFT JOIN Sellers$ C
ON B.seller_id = C.seller_id
LEFT JOIN Orders$ D
ON A.orden_id = D.order_id
LEFT JOIN Customers$ E
ON D.customer_id = E.customer_id

) AS sub_consulta
ORDER BY dias_diferencia DESC

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ANÁLISIS CON VISIÓN DE NEGOCIO/REVENUE
-- kpi's:

-- TOTAL DE PAGOS

--preguntas claves:

--1. ¿Cuál fue la suma del total de pagos que se cerró al primer día de cada mes? muestre el total acumulado de los pagos MoM (Month-over-Month)


WITH cte_1 AS (
    SELECT
        B.order_approved_at AS fecha_de_pago,
        TRY_CAST(A.payment_value AS numeric) AS conversion
    FROM Payments$ A
    LEFT JOIN Orders$ B ON A.order_id = B.order_id
),
cte_2 AS (
    SELECT
        fecha_de_pago,
        DATETRUNC(MONTH, fecha_de_pago) AS fecha_truncada,
        conversion
    FROM cte_1
),
cte_3 AS (
    SELECT
        fecha_truncada,
        SUM(conversion) AS total_pagos_numerico
    FROM cte_2
    WHERE fecha_truncada IS NOT NULL
    GROUP BY fecha_truncada
)
SELECT 
    fecha_truncada,
    FORMAT(total_pagos_numerico, 'C', 'en-US') AS total_pagos_mes,
    FORMAT(
        SUM(total_pagos_numerico) OVER (ORDER BY fecha_truncada ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
        'C', 'en-US'
    ) AS total_pagos_acumulado_por_mes
FROM cte_3
ORDER BY fecha_truncada ASC;


--2. ¿Cómo fue la distribución de los medios de pago para cada categoría de productos? muestre los primeros 5 estados para cada medio de pago y
--por estado/provincia en orden descendente

SELECT
	estado,
	medio_pago,
	categoría,
	FORMAT(total_pagos,'C', 'en-US') AS monto_total
FROM(
	SELECT 
		estado,
		medio_pago,
		total_pagos,
		categoría,
		ROW_NUMBER() OVER(PARTITION BY medio_pago ORDER BY medio_pago, total_pagos DESC) AS ranking
	FROM(
		SELECT 
			A.customer_state AS estado,
			C.payment_type AS medio_pago,
			E.product_category_name AS categoría,
			SUM(TRY_CAST(C.payment_value AS NUMERIC)) AS total_pagos
		FROM Customers$ A
		LEFT JOIN Orders$ B
		ON A.customer_id = B.customer_id
		LEFT JOIN Payments$ C
		ON B.order_id = C.order_id
		LEFT JOIN ['Orders items$'] D
		ON B.order_id = D.order_id
		LEFT JOIN Products$ E
		ON D.product_id = E.product_id
		WHERE 1=1
		AND C.payment_type IS NOT NULL
		AND E.product_category_name IS NOT NULL
		AND C.payment_type != 'not_defined'
		GROUP BY A.customer_state, C.payment_type, E.product_category_name
	) AS sub_consulta_1
) AS sub_consulta_2
WHERE
1=1
AND ranking < 6;


-- UTILIDADES

--preguntas claves:

--1. Identificar compras recurrentes en intervalos de tiempo de 30 DÍAS y mostrar las utilidades que dejaron los 5 mejores clientes. ¿Qué clientes fueron y de donde fueron? 



CREATE VIEW utilidadesV5 AS
SELECT
	A.customer_id AS cliente,
	A.order_purchase_timestamp AS fecha_compra,
	A.order_status,
	B.order_id,
	B.product_id,
	COALESCE(SUM(TRY_CAST(B.price AS NUMERIC))*1.0 - SUM(TRY_CAST(B.freight_value AS NUMERIC))*1.0,0) AS utilidad
FROM Orders$ A
LEFT JOIN ['Orders items$'] B
ON A.order_id = B.order_id
GROUP BY A.customer_id, A.order_purchase_timestamp, A.order_status, B.order_id, B.product_id;

----------------------------------------------------------------------------------------------------------------

CREATE VIEW CTE_recursivo AS
WITH cte_recursivo AS(

	SELECT
		cliente,
		fecha_compra,
		order_status,
		order_id,
		product_id,
		utilidad,
		ROW_NUMBER() OVER(PARTITION BY cliente ORDER BY utilidad DESC) AS nivel_productos,
		1 AS nivel_compra
	FROM utilidadesV5
	WHERE 1=1
	AND DATEDIFF(DAY,DATEADD(MONTH,-1,fecha_compra),fecha_compra) < 30   -- Compras recurrentes en intervalos de 30 días antes

	UNION ALL
	
	SELECT
		A.cliente,
		A.fecha_compra,
		A.order_status,
		A.order_id,
		A.product_id,
		A.utilidad,
		B.nivel_productos,
		B.nivel_compra + 1 AS nivel_compra

	FROM utilidadesV5 A
	INNER JOIN cte_recursivo B
	ON A.cliente = b.cliente            -- Busca que sea el mismo cliente 
	AND A.order_id > B.order_id         -- Pero diferente órden de compra para ejecutar el contador de "nivel_compra"

)
SELECT * FROM cte_recursivo
WHERE 1=1
AND order_status NOT IN ('unavailable', 'canceled')


----------------------------------------------------------------------------------------------
SELECT TOP 5 *
FROM (
	SELECT
		A.cliente,
		B.customer_city,
		SUM(A.utilidad)  AS utilidad
	FROM CTE_recursivo A
	LEFT JOIN Customers$ B
	ON A.cliente = B.customer_id
	GROUP BY cliente, customer_city
) AS subconsulta
ORDER BY utilidad DESC





-- FLUJO DE CAJA

--preguntas claves:

--1. ¿Con qué medio de pago se registró la compra más alta que se pagó de contado y en qué fecha se ejecutó la compra? 
--2. ¿Cuál fue el TOP 5 de vendedores que más flujo de caja obtuvieron de sus ventas? 

