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

**¿Se puede optimizar la consulta?**

Para la ejecución de esta consulta se requirieron datos de 5 tablas diferentes, lo cual demoró más de lo normal en el proceso de mostrar los resultados. A cuntinuación una imagen que resume el plan de ejecución de la consulta con su respectivo costo en cada paso que se le dijo que hiciera en el código. 


<img width="1609" height="410" alt="image" src="https://github.com/user-attachments/assets/4e004553-6f82-47dc-a3d3-fa6fa2851900" />


Para optimizar esta consulta y hacer que el código se ejecute más rápido y con menos recursos se crearon los siguientes índices (no agrupados) sobre algunas columnas requeridas en la consulta. 

> [!TIP]
> Un índice funciona como una tabla de contenido en un libro, es decir que el objetivo es que si quieres un capítulo puntual, no inspecciones todos los capítulos sino solamente el que quieres obtener.

```bash
CREATE NONCLUSTERED INDEX IDX_order
ON [dbo].['Orders items$'] ([order_id],[seller_id])


CREATE NONCLUSTERED INDEX IDX_seller
ON [dbo].[Sellers$] ([seller_id])


CREATE NONCLUSTERED INDEX IDX_customer
ON [dbo].[Customers$] ([customer_id])


CREATE NONCLUSTERED INDEX IDX_order_delivered
ON [dbo].[Orders$] ([order_status],[order_delivered_customer_date],[order_purchase_timestamp])
```
Luego de la creación de estos índices, **el plan de ejecución de la consulta redujo un 49% su tiempo de ejecución.** 


<img width="1874" height="512" alt="image" src="https://github.com/user-attachments/assets/afef21eb-84ad-4b7f-840c-1f40e1bf0b04" />


-----------------------------------------------------------------------------------------------------------------------------------------------------------

## Análisis con visión de negocio/revenue

### Ingresos

#### 1. ¿Cuál fue la suma del total de pagos que se cerró al primer día de cada mes? muestre el total acumulado de los pagos MoM (Month-over-Month)

```bash
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
```

#### Resultado

```bash
/*-------------------------+------------------+----------------------------------+
 | fecha_truncada          | total_pagos_mes  | total_pagos_acumulado_por_mes    |
 +-------------------------+------------------+----------------------------------+
 | 2016-10-01 00:00:00.000 | $58,378.00       | $58,378.00                       |
 | 2016-12-01 00:00:00.000 | $20.00           | $58,398.00                       |
 | 2017-01-01 00:00:00.000 | $131,871.00      | $190,269.00                      |
 | 2017-02-01 00:00:00.000 | $291,875.00      | $482,144.00                      |
 | 2017-03-01 00:00:00.000 | $446,126.00      | $928,270.00                      |
 | 2017-04-01 00:00:00.000 | $413,607.00      | $1,341,877.00                    |
 | 2017-05-01 00:00:00.000 | $593,191.00      | $1,935,068.00                    |
 | 2017-06-01 00:00:00.000 | $515,389.00      | $2,450,457.00                    |
 | 2017-07-01 00:00:00.000 | $585,338.00      | $3,035,795.00                    |
 | 2017-08-01 00:00:00.000 | $672,900.00      | $3,708,695.00                    |
 | 2017-09-01 00:00:00.000 | $717,963.00      | $4,426,658.00                    |
 | 2017-10-01 00:00:00.000 | $783,021.00      | $5,209,679.00                    |
 | 2017-11-01 00:00:00.000 | $1,175,088.00    | $6,384,767.00                    |
 | 2017-12-01 00:00:00.000 | $902,617.00      | $7,287,384.00                    |
 | 2018-01-01 00:00:00.000 | $1,106,268.00    | $8,393,652.00                    |
 | 2018-02-01 00:00:00.000 | $984,601.00      | $9,378,253.00                    |
 | 2018-03-01 00:00:00.000 | $1,170,322.00    | $10,548,575.00                   |
 | 2018-04-01 00:00:00.000 | $1,137,568.00    | $11,686,143.00                   |
 | 2018-05-01 00:00:00.000 | $1,180,079.00    | $12,866,222.00                   |
 | 2018-06-01 00:00:00.000 | $1,027,913.00    | $13,894,135.00                   |
 | 2018-07-01 00:00:00.000 | $1,043,078.00    | $14,937,213.00                   |
 | 2018-08-01 00:00:00.000 | $1,035,332.00    | $15,972,545.00                   |
 | 2018-09-01 00:00:00.000 | $166.00          | $15,972,711.00                   |
 +-------------------------+------------------+----------------------------------+*/

```

#### 2. ¿Cómo fue la distribución de los medios de pago para cada categoría de productos? muestre los primeros 5 estados para cada medio de pago por estado/provincia en orden descendente


```bash
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
AND ranking < 6
```

#### Resultado

```bash
/*-------+-------------+--------------------------+--------------+
| estado | medio_pago  | categoría                | monto_total  |
+--------+-------------+--------------------------+--------------+
| RJ     | debit_card  | relogios_presentes       | $14,069.00   |
| SP     | debit_card  | cama_mesa_banho          | $12,521.00   |
| SP     | debit_card  | utilidades_domesticas    | $9,653.00    |
| SP     | debit_card  | beleza_saude             | $9,599.00    |
| SP     | debit_card  | informatica_acessorios   | $8,079.00    |
| SP     | voucher     | cama_mesa_banho          | $17,030.00   |
| SP     | voucher     | utilidades_domesticas    | $15,108.00   |
| SP     | voucher     | moveis_decoracao         | $14,137.00   |
| SP     | voucher     | esporte_lazer            | $12,760.00   |
| SP     | voucher     | beleza_saude             | $9,913.00    |
| SP     | credit_card | cama_mesa_banho          | $610,180.00  |
| SP     | credit_card | beleza_saude             | $495,201.00  |
| SP     | credit_card | relogios_presentes       | $419,648.00  |
| SP     | credit_card | moveis_decoracao         | $415,317.00  |
| SP     | credit_card | esporte_lazer            | $400,034.00  |
| SP     | boleto      | informatica_acessorios   | $229,275.00  |
| SP     | boleto      | cama_mesa_banho          | $126,058.00  |
| SP     | boleto      | moveis_decoracao         | $117,801.00  |
| SP     | boleto      | esporte_lazer            | $104,571.00  |
| SP     | boleto      | beleza_saude             | $101,444.00  |
+--------+-------------+--------------------------+--------------+*/
```

### Utilidades

#### 1. Identificar compras recurrentes en intervalos de tiempo de 30 días y mostrar las utilidades que dejaron los 5 mejores clientes. ¿Qué clientes fueron y de donde fueron? 

Para este problema inicialmente se creó la siguiente vista que traía los datos que se necesitaban para responder a esta consulta: 

```bash
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
```

Para realizar la medición de las compras recurrentes se relacionó para cada cliente el número de orders_id (sin discriminar cuántos productos habían por order_id ya que en el dataset todos los productos de cada order_id aparecen comprados en la misma fecha y hora), pero si se realizó un conteo de productos por orden con la función de ventana ROW_NUMBER(). Como lo que se pensaba era un conteo incremental para cada cliente que compró más de una order_id en un lapso de menos de 30 días se muestra el siguiente CTE recursivo:

```bash
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
```
> [!NOTE]
> Para esta vista se filtraron aquellos niveles de compra que eran mayores a 1 (nivel_compra > 1) para identificar los clientes que compraron más de una vez en el intervalo de tiempo de 30 días. Sin embargo, el resultado fue nulo ya que en el dataset solo registra una order_id por cada customer_id. Pero en la práctica, esto no sucede, por lo que quería mostrar cómo se resolvería este tipo de preguntas. 

Finalmente, para sintetizar las vistas anteriores y responder a la pregunta de negocio, se plantea la siguiente consulta:

```bash
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
```

#### Resultado

```bash
/*----------------------------------+------------------------+----------+
 | cliente                          | customer_city          | utilidad |
 +----------------------------------+------------------------+----------+
 | 35a413c7ca3c69756cb75867d6311c0d | bom jesus do galho     | 4025.0   |
 | c6695e3b1e48680db36b487419fb0398 | sao paulo              | 3983.0   |
 | 19b32919fa1198aefc0773ee2e46e693 | recife                 | 3607.0   |
 | fd78e5e3abdc375368456fe738694c00 | monte alegre do sul    | 2976.0   |
 | d7c94e22bfd332eb29b0f5badc3ce103 | varginha               | 2958.0   |
 +----------------------------------+------------------------+----------+*/
```

### Flujo de caja

#### 1. ¿Con qué medio de pago se registró la compra más alta que se pagó de contado? ¿qué cliente la hizo y en qué fecha se ejecutó la compra? ¿cuánto dejó de utilidad esa compra?

```bash
SELECT
	TOP 1 *
FROM(
SELECT
	A.payment_type,
	B.customer_id,
	B.order_purchase_timestamp,
	MAX(A.payment_value) AS pago_máximo,
	C.utilidad AS flujo_caja_máximo  
FROM Payments$ A
LEFT JOIN Orders$ B
ON A.order_id = B.order_id
LEFT JOIN utilidadesV5 C
ON A.order_id = C.order_id
WHERE 1=1
AND payment_installments = 1	--compra que se pagó de contado o una sola vez 
GROUP BY payment_type, customer_id, order_purchase_timestamp, utilidad
) AS subconsulta
ORDER BY pago_máximo DESC
```

#### Resultado

```bash
/*----------------+----------------------------------+--------------------------+-------------+-------------------+
 | payment_type   | customer_id                      | order_purchase_timestamp | pago_máximo | flujo_caja_máximo |
 +----------------+----------------------------------+--------------------------+-------------+-------------------+
 | boleto         | 7ce1fc9e99a49468fd3ba1df06317ff3 | 2017-09-18 15:55:33.000  | 999.68      | 600.0             |
 +----------------+----------------------------------+--------------------------+-------------+-------------------+*/
```
#### 2. ¿Cuál fue la compra a la que más cuotas se difirió un pago?

```bash
SELECT
	TOP 1 *
FROM(
SELECT
	A.payment_type,
	B.customer_id,
	B.order_purchase_timestamp,
	A.payment_installments AS cuotas,
	MAX(A.payment_value) AS pago
FROM Payments$ A
LEFT JOIN Orders$ B
ON A.order_id = B.order_id
WHERE 1=1
AND payment_installments = (SELECT MAX(payment_installments) FROM Payments$)	--compra que se pagó en más cuotas
GROUP BY payment_type, customer_id, order_purchase_timestamp, payment_installments
) AS subconsulta
ORDER BY pago DESC
```
#### Resultado

```bash
/*--------------+----------------------------------+--------------------------+-------+--------+
 | payment_type | customer_id                      | order_purchase_timestamp | cuotas | pago   |
 +--------------+----------------------------------+--------------------------+-------+--------+
 | credit_card  | 7bb5a75d4a412872fa774b56e05d0c38 | 2017-11-27 20:01:56.000  | 24     | 771.69 |
 +--------------+----------------------------------+--------------------------+-------+--------+*/
```

#### 3. ¿Cuál fue el TOP 5 de vendedores que más flujo de caja inmediato obtuvieron de sus ventas y cuántas ventas realizaron?

```bash
SELECT
	TOP 5 *
FROM(
	SELECT
		A.seller_id,
		COALESCE(SUM(TRY_CAST(A.price AS NUMERIC))*1.0 - SUM(TRY_CAST(A.freight_value AS NUMERIC))*1.0,0) AS flujo_caja,
		COUNT(B.order_id) AS cantidad_ventas
	FROM ['Orders items$'] A
	LEFT JOIN  Orders$ B
	ON A.order_id = B.order_id
	LEFT JOIN Payments$ C
	ON B.order_id = C.order_id
	WHERE 1=1
	AND C.payment_installments = 1	--compra que se pagó de contado
	AND C.payment_type NOT IN ('credit_card')
	GROUP BY seller_id
) AS subconsulta
ORDER BY flujo_caja DESC
```

#### Resultado

```bash
/*----------------------------------+------------+-----------------+
 | seller_id                        | flujo_caja | cantidad_ventas |
 +----------------------------------+------------+-----------------+
 | 53243585a1d6dc2643021fd1853d8905 | 44328.0    | 96              |
 | 7c67e1448b00f6e969d365cea6b010ab | 43273.0    | 464             |
 | 4a3ca9315b744ce9f8e9374361493884 | 39567.0    | 544             |
 | 4869f7a5dfa277a7dca6462dcf3b52b2 | 38778.0    | 217             |
 | da8622b14eb17ae2831f4ac5b9dab84a | 34128.0    | 452             |
 +----------------------------------+------------+-----------------+*/
```

