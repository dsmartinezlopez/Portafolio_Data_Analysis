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

#### Resultado

```bash
/*-------------------------+--------------------------+---------------------+
| total_pedidos_enviados   | pedidos_que_cumplieron   | pedidos_retrasados  |
+--------------------------+--------------------------+---------------------+
| 96470                    | 19823                    | 76647               |
+--------------------------+--------------------------+---------------------+*/
```

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

#### Resultado

```bash
/*-----+-----------+---------------------+----------+
| año  | mes       | pedidos_retrasados  | variación|
+------+-----------+---------------------+----------+
| 2016 | September | 1                   | NULL     |
| 2016 | October   | 251                 | 25,000%  |
| 2016 | December  | 1                   | -100%    |
| 2017 | January   | 702                 | 70,100%  |
| 2017 | February  | 1483                | 111%     |
| 2017 | March     | 1952                | 32%      |
| 2017 | April     | 1879                | -4%      |
| 2017 | May       | 2671                | 42%      |
| 2017 | June      | 2476                | -7%      |
| 2017 | July      | 2995                | 21%      |
| 2017 | August    | 3108                | 4%       |
| 2017 | September | 3253                | 5%       |
| 2017 | October   | 3446                | 6%       |
| 2017 | November  | 6112                | 77%      |
| 2017 | December  | 4543                | -26%     |
| 2018 | January   | 5791                | 27%      |
| 2018 | February  | 5706                | -1%      |
| 2018 | March     | 5837                | 2%       |
| 2018 | April     | 5028                | -14%     |
| 2018 | May       | 5128                | 2%       |
| 2018 | June      | 4483                | -13%     |
| 2018 | July      | 4769                | 6%       |
| 2018 | August    | 5032                | 6%       |
+------+-----------+---------------------+----------+*/
```


#### 3. Si la clasificación de los productos se establece de acuerdo al peso, donde SMALL se denomina todo lo que pese <= 1000 gramos, MEDIUM todo lo que pese > 1000 gramos y <= 10000 gramos, y BIG todo lo que pese > 10000 gramos ¿cuales fueron las clasificaciones que más porcentaje de incumplimiento tuvieron ordenadas de forma descendente?

```bash
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
```

#### Resultado

```bash
/*-------------+------------------+--------------------+------------+
|clasificación | pedidos_enviados | pedidos_retrasados | porcentaje |
+--------------+------------------+--------------------+------------+
| MEDIUM       | 38542            | 31702              | 82.25%     |
| BIG          | 5155             | 4215               | 81.77%     |
| SMALL        | 66474            | 51403              | 77.33%     |
+--------------+------------------+--------------------+------------+*/
```

#### 4. ¿Cuál fue el TOP 20 de órdenes_id enviadas que más se demoraron en completarse? muestre id de la orden, producto(s), ciudad origen (vendedor), ciudad destino (comprador) y cantidad de días transcurridos desde la fecha de compra y la fecha de entrega. 

```bash
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
```

#### Resultado

```bash
/*---------------------------------+----------------------------------+---------------------+----------------------+-------------------------+-------------------------+------------------+
| orden_id                         | product_id                       | ciudad_origen       | ciudad_destino       | fecha_compra            | fecha_envío             | dias_diferencia  |
+----------------------------------+----------------------------------+---------------------+----------------------+-------------------------+-------------------------+------------------+
| ca07593549f1816d26a572e06dc1eab6 | 8eed5d27f5b8c6248731efb4782f6141 | belo horizonte      | montanha             | 2017-02-21 23:31:27.000 | 2017-09-19 14:36:39.000 | 210              |
| 1b3190b2dfa9d789e1f14c05b647a14a | ee406bf28024d97771c4b1e8b7e8e219 | sao paulo           | rio de janeiro       | 2018-02-23 14:57:35.000 | 2018-09-19 23:24:07.000 | 208              |
| 440d0d17af552815d15a9e41abe49359 | 3bec03860f3782ef8993056e01b8229a | belo horizonte      | belem                | 2017-03-07 23:59:51.000 | 2017-09-19 15:12:50.000 | 196              |
| 2fb597c2f772eca01b1f5c561bf6cc7b | 8ed094bfe076c568f6bb10feada3f75d | itaquaquecetuba     | teresina             | 2017-03-08 18:09:02.000 | 2017-09-19 14:33:17.000 | 195              |
| 285ab9426d6982034523a855f55a885e | 0c6fc9b9317a68d1cda098c063914b72 | uberaba             | lagarto              | 2017-03-08 22:47:40.000 | 2017-09-19 14:00:04.000 | 195              |
| 0f4519c5f1c541ddec9f21b3bddd533a | e0d64dcfaa3b6db5c54ca298ae101d05 | barueri             | teresina             | 2017-03-09 13:26:57.000 | 2017-09-19 14:38:21.000 | 194              |
| 47b40429ed8cce3aee9199792275433f | ebf1c13032246ea801765e8cb5417365 | sao paulo           | salto                | 2018-01-03 09:44:01.000 | 2018-07-13 20:51:31.000 | 191              |
| 2fe324febf907e3ea3f2aa9650869fa5 | b75683e29689c1a989ae97883e8cad56 | farroupilha         | paulinia             | 2017-03-13 20:17:10.000 | 2017-09-19 17:00:07.000 | 190              |
| c27815f7e3dd0b926b58552628481575 | 05e8eca656b87428a0e8453a2f335cdf | itajobi             | perdizes             | 2017-03-15 23:23:17.000 | 2017-09-19 17:14:25.000 | 188              |
| 2d7561026d542c8dbd8f0daeadf67a43 | 7594c5fa74bceda1c2540003533a6e02 | aracatuba           | aracaju              | 2017-03-15 11:24:27.000 | 2017-09-19 14:38:18.000 | 188              |
| 437222e3fd1b07396f1d9ba8c15fba59 | f82a4b08cf7b2bf375fb77e519231f9a | ibitinga            | macapa               | 2017-03-16 11:36:00.000 | 2017-09-19 16:28:58.000 | 187              |
| 437222e3fd1b07396f1d9ba8c15fba59 | 5215eef690e61a0c178ed552e6e2d06a | ibitinga            | macapa               | 2017-03-16 11:36:00.000 | 2017-09-19 16:28:58.000 | 187              |
| dfe5f68118c2576143240b8d78e5940a | aba86c093ccdbac75b09111d57e50004 | itaquaquecetuba     | teutonia             | 2017-03-17 12:32:22.000 | 2017-09-19 18:13:19.000 | 186              |
| 6e82dcfb5eada6283dba34f164e636f5 | 3ce943997ff85cad84ec6770b35d6bcd | sao jose dos campos | santa maria          | 2017-05-17 19:09:02.000 | 2017-11-16 10:56:45.000 | 183              |
| 6e82dcfb5eada6283dba34f164e636f5 | b7d94dc0640c7025dc8e3b46b52d8239 | sao jose dos campos | santa maria          | 2017-05-17 19:09:02.000 | 2017-11-16 10:56:45.000 | 183              |
| 2ba1366baecad3c3536f27546d129017 | e4176515d2055eb7771645c597f8b40c | sao jose dos campos | formosa              | 2017-02-28 14:56:37.000 | 2017-08-28 16:23:46.000 | 181              |
| d24e8541128cea179a11a65176e0a96f | a224196b0b605fdffac1d9224f052ceb | indaiatuba          | sao bernardo do campo| 2017-06-12 13:14:11.000 | 2017-12-04 18:36:29.000 | 175              |
| d24e8541128cea179a11a65176e0a96f | 4f687412e6805c3cfc9e0c5ec2f841e0 | indaiatuba          | sao bernardo do campo| 2017-06-12 13:14:11.000 | 2017-12-04 18:36:29.000 | 175              |
| 3566eabb132f8d64741ae7b921bbd10e | 35afc973633aaeb6b877ff57b2793310 | ibitinga            | currais novos        | 2017-03-29 13:57:55.000 | 2017-09-19 15:07:09.000 | 174              |
| ed8e9faf1b75f43ee027103957135663 | bdeb69e094c42de582310fffad126d77 | bebedouro           | jacarei              | 2017-11-29 15:10:14.000 | 2018-05-21 18:22:18.000 | 173              |
+----------------------------------+----------------------------------+---------------------+----------------------+-------------------------+-------------------------+------------------+*/

```

<img width="1609" height="410" alt="image" src="https://github.com/user-attachments/assets/4e004553-6f82-47dc-a3d3-fa6fa2851900" />

-----------------------------------------------------------------------------------------------------------------------------------------------------------

## Análisis con visión de negocio/revenue

### Ingresos

#### 1. ¿Cuál fue la suma del total de pagos que se cerró al primer día de cada mes? muestre el total acumulado de los pagos MoM (Month-over-Month)

```bash
```

#### Resultado

```bash
```

#### 2. ¿Cómo fue la distribución de los medios de pago para cada categoría de productos? muestre la composición porcentual para cada medio de pago por estado/provincia

```bash
```

#### Resultado

```bash
```

### Utilidades

#### 1. ¿Cuáles fueron el TOP 3 de ciudades por cada estado que más utilidades obtuvieron? 

```bash
```

#### Resultado

```bash
```

### Flujo de caja

#### 1. ¿Con qué medio de pago se registró la compra más alta que se pagó de contado y en qué fecha se ejecutó la compra? 

```bash
```

#### Resultado

```bash
```

#### 2. ¿Cuál fue el TOP 5 de vendedores que más flujo de caja obtuvieron de sus ventas? 

```bash
```

#### Resultado

```bash
```

