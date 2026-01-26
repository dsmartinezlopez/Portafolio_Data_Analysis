## Proyecto Brazilian E-commerce

Esta es una explicación de paso por paso en MS SQL Server para el desarrollo de este proyecto.

Código completo: [E-commerce Brazil](https://github.com/dsmartinezlopez/Portafolio_Data_Analysis/blob/Portafolio-projects-1/SQLQueryProyectoEcommerceBrazil.sql)

> [!NOTE]
> Si tienes instalado en tu PC MS SQL Server puedes copiar y pegar todo el código completo. Sin embargo, para efectos de organización a continuación se muestra el paso a paso de lo que se realizó.


## Etapa de exploración - preguntas de negocio

## Análisis con visión operativa

#### 1. ¿Cuál fue el volumen de pedidos enviados y cuántos cumplieron el tiempo de entrega y cuántos no?

```bash
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
FROM cte_3
```

#### Resultado:

+--------------------------+--------------------------+--------------------------+
| total_pedidos_enviados   | pedidos_que_cumplieron   | pedidos_retrasados       |
+--------------------------+--------------------------+--------------------------+
| 96470                    | 19823                    | 76647                    |
+--------------------------+--------------------------+--------------------------+

#### 2. ¿Cuál es el GAP de incumplimiento de entregas comparando MoM (Month-over-Month) de cada año?

Reutilizamos la información obtenida de la consulta anterior para crear una vista que va a ser de utilidad para el análisis de cumplimientos e incumplimientos. 

```bash
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
```

Ya una vez creada la vista, procedemos a dar respuesta a la pregunta de negocio.

```bash
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
```

#### 3. Si la clasificación de los productos se establece de acuerdo al peso, donde SMALL se denomina todo lo que pese <= 1000 gramos, MEDIUM todo lo que pese > 1000 gramos y <= 10000 gramos, y BIG todo lo que pese > 10000 gramos ¿cuales fueron las clasificaciones que más porcentaje de incumplimiento tuvieron ordenadas de forma descendente?

```bash
```

#### 4. ¿Cuál fue el TOP 5 de órdenes_id enviadas que más se demoraron en completarse? muestre id de la orden, producto(s), ciudad origen (vendedor), ciudad destino (comprador) y cantidad de días transcurridos desde la fecha de compra y la fecha de entrega. 

```bash
```

-----------------------------------------------------------------------------------------------------------------------------------------------------------

## Análisis con visión de negocio/revenue

### Ingresos

#### 1. ¿Cuál fue la suma del total de pagos que se cerró al primer día de cada mes? muestre el total acumulado de los pagos MoM (Month-over-Month)

```bash
```

#### 2. ¿Cómo fue la distribución de los medios de pago para cada categoría de productos? muestre la composición porcentual para cada medio de pago por estado/provincia

```bash
```

### Utilidades

#### 1. ¿Cuáles fueron el TOP 3 de ciudades por cada estado que más utilidades obtuvieron? 

```bash
```

### Flujo de caja

#### 1. ¿Con qué medio de pago se registró la compra más alta que se pagó de contado y en qué fecha se ejecutó la compra? 

```bash
```

#### 2. ¿Cuál fue el TOP 5 de vendedores que más flujo de caja obtuvieron de sus ventas? 

```bash
```

