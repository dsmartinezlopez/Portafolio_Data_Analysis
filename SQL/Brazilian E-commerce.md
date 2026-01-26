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

#### 2. ¿Cuál es el GAP de incumplimiento de entregas comparando MoM (Month-over-Month) de cada año?

```bash
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

