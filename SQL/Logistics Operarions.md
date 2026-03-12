## Proyecto Logistics Operations

Esta es una explicación de paso por paso en MS SQL Server para el desarrollo de este proyecto.

Código completo:

> [!NOTE]
> Si tienes instalado en tu PC MS SQL Server puedes copiar y pegar todo el código completo. Sin embargo, para efectos de organización a continuación se muestra el paso a paso de lo que se realizó.

## Etapa de exploración - preguntas de negocio

### On time delivery metrics

#### 1. Calcule la cantidad de viajes retrasados para cada DRIVER, además devuelva la tasa de retraso en % con 1 decimal. Considere únicamente los DRIVERS que hicieron +700 viajes y genere un ranking por la tasa de retraso y ordénelo de mayor a menor. Calcule además el total de revenue para cada driver.

```bash
SELECT
	driver_id,
	cantidad_viajes,
	CAST(cantidad_viajes - ((1-tasa_retraso)*cantidad_viajes) AS int) AS cantidad_viajes_retrasados,
	FORMAT(tasa_retraso, 'P1') AS tasa_retraso,
	total_revenue
FROM (
	SELECT 
		driver_id,
		SUM(TRY_CAST(trips_completed AS numeric)) AS cantidad_viajes,
		AVG(TRY_CAST(on_time_delivery_rate AS float)) AS tasa_retraso,
		FORMAT(SUM(TRY_CAST(total_revenue AS numeric)), 'C') AS total_revenue
	FROM driver_monthly_metrics$
	GROUP BY driver_id
	HAVING SUM(TRY_CAST(trips_completed AS numeric)) > 700
) AS sub
ORDER BY tasa_retraso DESC
```
#### Resultado

```bash
/*----------+-----------------+----------------------------+--------------+-----------------+
| driver_id | cantidad_viajes | cantidad_viajes_retrasados | tasa_retraso | total_revenue   |
+-----------+-----------------+----------------------------+--------------+-----------------+
| DRV00108  | 735             | 350                        | 47.7%        | $2,311,329.00   |
| DRV00139  | 710             | 330                        | 46.5%        | $2,152,412.00   |
| DRV00099  | 711             | 328                        | 46.2%        | $2,158,400.00   |
| DRV00059  | 729             | 335                        | 46.0%        | $2,305,055.00   |
| DRV00085  | 703             | 319                        | 45.4%        | $2,229,522.00   |
| DRV00149  | 721             | 326                        | 45.2%        | $2,269,105.00   |
| DRV00130  | 701             | 315                        | 45.0%        | $2,118,376.00   |
| DRV00016  | 712             | 320                        | 45.0%        | $2,278,576.00   |
| DRV00019  | 749             | 336                        | 44.9%        | $2,275,651.00   |
| DRV00024  | 708             | 317                        | 44.8%        | $2,166,574.00   |
| DRV00147  | 705             | 315                        | 44.7%        | $2,256,066.00   |
| DRV00142  | 711             | 318                        | 44.7%        | $2,143,054.00   |
| DRV00038  | 705             | 313                        | 44.5%        | $2,160,496.00   |
| DRV00078  | 717             | 318                        | 44.4%        | $2,167,291.00   |
| DRV00066  | 737             | 327                        | 44.4%        | $2,180,636.00   |
| DRV00010  | 709             | 310                        | 43.7%        | $2,144,656.00   |
| DRV00051  | 723             | 313                        | 43.4%        | $2,311,845.00   |
| DRV00014  | 707             | 306                        | 43.3%        | $2,174,425.00   |
| DRV00150  | 706             | 303                        | 43.0%        | $2,075,242.00   |
| DRV00124  | 702             | 296                        | 42.2%        | $2,084,929.00   |
| DRV00092  | 711             | 299                        | 42.1%        | $2,173,931.00   |
| DRV00127  | 702             | 295                        | 42.1%        | $2,272,321.00   |
| DRV00087  | 725             | 303                        | 41.9%        | $2,214,001.00   |
+-----------+-----------------+----------------------------+--------------+-----------------+*/
```

#### 2. ¿Cuáles fueron las marcas de vehículos que más se utilizaron para la realizar los viajes? Muestre la cantidad de viajes realizados y la cantidad de viajes retrasados. Además muestre para cada marca la cantidad de vehículos que estuvieron más de una vez en mantenimiento en un rango de 1 semana y la cantidad de accidentes registrados.

```bash
WITH full_rate AS(
	SELECT
		driver_id,
		SUM(TRY_CAST(trips_completed AS numeric)) AS cantidad_viajes,
		SUM(TRY_CAST(trips_completed AS numeric)) - SUM(TRY_CAST(trips_completed AS numeric) * TRY_CAST(on_time_delivery_rate AS numeric)) AS viajes_retrasados
	FROM driver_monthly_metrics$
    GROUP BY driver_id
),

utilization_mark AS(
	SELECT
		tp.driver_id,
		t.make AS marca,
		COUNT(tp.trip_id) AS cantidad_viajes
	FROM trucks$ t
	INNER JOIN trips$ tp
	ON t.truck_id = tp.truck_id
	GROUP BY tp.driver_id, t.make
),

incumplimiento_por_mark AS(
	SELECT
		u.marca AS marca,
		SUM(u.cantidad_viajes) AS cantidad_viajes,
		SUM((u.cantidad_viajes/ NULLIF(f.cantidad_viajes, 0)) * f.viajes_retrasados) AS retrasos_proporcionales
	FROM utilization_mark u
	LEFT JOIN full_rate f
	ON u.driver_id = f.driver_id
	GROUP BY u.marca
),
accidentes_mantenimientos AS (
	SELECT
	    t.make AS marca,
	    COUNT(s.incident_id) AS cantidad_accidentes,
	    COUNT(DISTINCT reincidentes.truck_id) AS vehiculos_con_mantenimiento_semanal
	FROM trucks$ t
	LEFT JOIN safety_incidents$ s 
	    ON t.truck_id = s.truck_id
	LEFT JOIN (
	    SELECT DISTINCT m1.truck_id
	    FROM maintenance_records$ m1
	    INNER JOIN maintenance_records$ m2 
	        ON m1.truck_id = m2.truck_id 
	        AND m1.maintenance_id <> m2.maintenance_id
	    WHERE m2.maintenance_date BETWEEN m1.maintenance_date AND DATEADD(DAY, 7, m1.maintenance_date)
	) AS reincidentes 
	    ON t.truck_id = reincidentes.truck_id
	GROUP BY t.make
)
SELECT
	um.marca AS marca,
	um.cantidad_viajes AS cantidad_viajes_completados,
	CAST(ROUND(um.retrasos_proporcionales, 0) AS int) AS cantidad_viajes_retrasados,
	cantidad_accidentes,
	vehiculos_con_mantenimiento_semanal
FROM incumplimiento_por_mark um
INNER JOIN accidentes_mantenimientos am
ON um.marca = am.marca
ORDER BY cantidad_viajes_completados DESC
```

#### Resultado

```bash
/*-------------+-------------------------------+------------------------------+-----------------------+-------------------------------------+
| marca        | cantidad_viajes_completados   | cantidad_viajes_retrasados   | cantidad_accidentes   | vehiculos_con_mantenimiento_semanal |
+--------------+-------------------------------+------------------------------+-----------------------+-------------------------------------+
| Volvo        | 17218                         | 10800                        | 34                    | 20                                  |
| International| 15450                         | 9728                         | 36                    | 18                                  |
| Peterbilt    | 14699                         | 9227                         | 29                    | 21                                  |
| Freightliner | 13660                         | 8593                         | 25                    | 21                                  |
| Mack         | 12681                         | 7972                         | 27                    | 20                                  |
| Kenworth     | 10030                         | 6313                         | 18                    | 14                                  |
+--------------+-------------------------------+------------------------------+-----------------------+-------------------------------------+*/
```

#### 3. ¿Cuales fueron los días de la semana donde más se registraron viajes retrasados? devuelva el resultado en formato de matriz con los días de la semana como columnas y las fechas de los despachos en formato "yyyy-mm" como filas.

Primeramente le indicamos al motor de SQL Server cúal sería el día a considerar como primer día de la semana, en este caso, le indicamos que el primer día de la semana es el día Domingo a través de:

```bash
SET DATEFIRST 7;
```

Procediendo a dar respuesta a la pregunta de negocio:

```bash
WITH viajes AS(
	SELECT
		tr.dispatch_date,
		FORMAT(tr.dispatch_date, 'yyyy-MM') AS Año_Mes,
		rpd.cantidad_viajes_retrasados AS viajes_retrasados
	FROM rendimiento_por_driver rpd
	JOIN trips$ tr
	ON rpd.driver_id = tr.driver_id

	GROUP BY tr.dispatch_date, rpd.cantidad_viajes_retrasados
)
SELECT 
	Año_Mes,
	[Lunes], 
	[Martes], 
	[Miércoles], 
	[Jueves], 
	[Viernes], 
	[Sábado], 
	[Domingo]
FROM (
    SELECT 
		Año_Mes,
        CASE DATEPART(WEEKDAY, dispatch_date)
            WHEN 1 THEN 'Domingo'
            WHEN 2 THEN 'Lunes'
            WHEN 3 THEN 'Martes'
            WHEN 4 THEN 'Miércoles'
            WHEN 5 THEN 'Jueves'
            WHEN 6 THEN 'Viernes'
            WHEN 7 THEN 'Sábado'
        END AS día,
        viajes_retrasados AS viajes
	FROM viajes 

) AS subquery
PIVOT
(
    COUNT(viajes)
    FOR día IN ([Lunes], [Martes], [Miércoles], [Jueves], [Viernes], [Sábado], [Domingo])
) AS pvt
ORDER BY Año_Mes ASC
```

#### Resultado

```bash
/*---------+-------+-------+-----------+--------+---------+--------+---------+
 | Año_Mes | Lunes | Martes| Miércoles | Jueves | Viernes | Sábado | Domingo |
 +---------+-------+-------+-----------+--------+---------+--------+---------+
 | 2022-01 | 200   | 144   | 151       | 154    | 157     | 184    | 192     |
 | 2022-02 | 163   | 143   | 150       | 158    | 150     | 155    | 159     |
 | 2022-03 | 150   | 205   | 197       | 205    | 157     | 153    | 146     |
 | 2022-04 | 153   | 154   | 168       | 152    | 191     | 190    | 150     |
 | 2022-05 | 191   | 197   | 161       | 163    | 155     | 141    | 180     |
 | 2022-06 | 161   | 159   | 187       | 188    | 163     | 151    | 159     |
 | 2022-07 | 165   | 140   | 150       | 141    | 190     | 190    | 195     |
 | 2022-08 | 203   | 187   | 181       | 154    | 166     | 151    | 156     |
 | 2022-09 | 152   | 147   | 145       | 193    | 185     | 150    | 149     |
 | 2022-10 | 183   | 151   | 154       | 149    | 140     | 193    | 196     |
 | 2022-11 | 155   | 189   | 205       | 149    | 151     | 145    | 158     |
 | 2022-12 | 143   | 149   | 155       | 191    | 192     | 192    | 162     |
 | 2023-01 | 191   | 200   | 146       | 153    | 151     | 155    | 181     |
 | 2023-02 | 158   | 151   | 149       | 160    | 150     | 146    | 156     |
 | 2023-03 | 155   | 150   | 182       | 187    | 195     | 160    | 140     |
 | 2023-04 | 156   | 165   | 148       | 145    | 154     | 197    | 187     |
 | 2023-05 | 182   | 186   | 168       | 156    | 152     | 158    | 148     |
 | 2023-06 | 154   | 151   | 165       | 184    | 183     | 141    | 153     |
 | 2023-07 | 198   | 150   | 147       | 165    | 140     | 193    | 182     |
 | 2023-08 | 156   | 182   | 179       | 186    | 163     | 151    | 159     |
 | 2023-09 | 140   | 157   | 144       | 149    | 200     | 186    | 154     |
 | 2023-10 | 188   | 179   | 155       | 158    | 145     | 147    | 188     |
 | 2023-11 | 158   | 152   | 193       | 188    | 158     | 157    | 151     |
 | 2023-12 | 144   | 149   | 146       | 149    | 190     | 184    | 180     |
 | 2024-01 | 192   | 202   | 191       | 157    | 147     | 156    | 142     |
 | 2024-02 | 156   | 164   | 144       | 186    | 153     | 142    | 144     |
 | 2024-03 | 158   | 147   | 145       | 157    | 170     | 204    | 189     |
 | 2024-04 | 191   | 198   | 156       | 152    | 160     | 151    | 168     |
 | 2024-05 | 149   | 155   | 197       | 199    | 186     | 145    | 152     |
 | 2024-06 | 155   | 152   | 155       | 161    | 153     | 199    | 191     |
 | 2024-07 | 182   | 185   | 182       | 157    | 158     | 147    | 155     |
 | 2024-08 | 152   | 150   | 156       | 197    | 191     | 196    | 149     |
 | 2024-09 | 195   | 165   | 153       | 151    | 157     | 147    | 174     |
 | 2024-10 | 163   | 195   | 193       | 190    | 166     | 135    | 160     |
 | 2024-11 | 145   | 152   | 157       | 155    | 187     | 196    | 150     |
 | 2024-12 | 185   | 192   | 158       | 161    | 147     | 152    | 175     |
 +---------+-------+-------+-----------+--------+---------+--------+---------+*/
```

#### 4. ¿Cual fue el tiempo promedio (en minutos) de eventos de detención reportados en los viajes para cada ciudad? Muestre el TOP 10 de ciudades con mayores tiempos y compare cuántos de esos eventos de detención terminaron afectando la tasa de cumplimiento.

```bash
```

#### Resultado

```bash
```


#### 5. La empresa ha decidido comisionar con 10% (sobre las utilidades) a los DRIVERS (con contrato activo y +5 años de experiencia) que generaron +2M de ingresos para la compañía. ¿Qienes son esos trabajadores y cuánto comisionaron?

```bash
```

#### Resultado

```bash
```
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																									
### Logistics network metrics

#### 1. Para cada tipo de facilities ¿cuales fueron el top 5 donde más pasaron los vehículos? Muestre en qué ciudad están ubicados y además calcule dentro de la misma query los subtotales de pedidos que pasaron por cada tipo de facility

```bash
```

#### Resultado

```bash
```

#### 2. Cree una tabla con las rutas asignadas de ciudades desde origen a destino. Contemple todos los puntos origen-destino de la red logística por los que pasaron los vehículos y compare la cantidad de viajes retrasados en cada ruta. Muestre el diseño de la red en un mapa como un Dashboard. 

Paso 1: Verificación esquema de la tabla de rutas

```bash
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'routes$'
```
Paso 2: Agregación de columnas de latitud y longitud al esquema de la tabla de rutas

```bash
ALTER TABLE routes$
ADD longitud_origin_city float,
	latitud_origin_city float,
	longitud_destination_city float,
	latitud_destination_city float 
```
Paso 3: Inserción de valores geoespaciales a ciudades origen y destino

```bash
--- agregación longitudes de ciudades de origen 

UPDATE routes$
SET longitud_origin_city =
	CASE
		WHEN origin_city = 'Atlanta' THEN -84.38798
		WHEN origin_city = 'Chicago' THEN -87.65005
		WHEN origin_city = 'Dallas' THEN -96.80667
		WHEN origin_city = 'New York' THEN -74.00597
		WHEN origin_city = 'Phoenix' THEN -112.07404
		WHEN origin_city = 'Philadelphia' THEN -75.16362
		WHEN origin_city = 'Houston' THEN -95.36327
		WHEN origin_city = 'Miami' THEN -80.19366
		WHEN origin_city = 'Detroit' THEN -83.04575
		WHEN origin_city = 'Seattle' THEN -122.33207
		WHEN origin_city = 'Denver' THEN -104.9847
		WHEN origin_city = 'Portland' THEN -122.67621
		WHEN origin_city = 'Las Vegas' THEN -115.13722
		WHEN origin_city = 'Minneapolis' THEN -93.26384
		WHEN origin_city = 'Charlotte' THEN -80.84313
		WHEN origin_city = 'Columbus' THEN -82.99879
		WHEN origin_city = 'Memphis' THEN -90.04898
		WHEN origin_city = 'Kansas City' THEN -94.57857
	ELSE longitud_origin_city
	END;

--- agregación latitudes de ciudades de origen 

UPDATE routes$
SET latitud_origin_city =
	CASE
		WHEN origin_city = 'Atlanta' THEN 33.749
		WHEN origin_city = 'Chicago' THEN 41.85003
		WHEN origin_city = 'Dallas' THEN 32.78306
		WHEN origin_city = 'New York' THEN 40.71427
		WHEN origin_city = 'Phoenix' THEN 33.44838
		WHEN origin_city = 'Philadelphia' THEN 39.95238
		WHEN origin_city = 'Houston' THEN 29.76328
		WHEN origin_city = 'Miami' THEN 25.77427
		WHEN origin_city = 'Detroit' THEN 42.33143
		WHEN origin_city = 'Seattle' THEN 47.60621
		WHEN origin_city = 'Denver' THEN 39.73915
		WHEN origin_city = 'Portland' THEN 45.52345
		WHEN origin_city = 'Las Vegas' THEN 36.17497
		WHEN origin_city = 'Minneapolis' THEN 44.97997
		WHEN origin_city = 'Charlotte' THEN 35.22709
		WHEN origin_city = 'Columbus' THEN 39.96118
		WHEN origin_city = 'Memphis' THEN 35.14953
		WHEN origin_city = 'Kansas City' THEN 39.09973
	ELSE latitud_origin_city
	END;


--- agregación longitudes de ciudades de destino 

UPDATE routes$
SET longitud_destination_city =
	CASE
		WHEN destination_city = 'Atlanta' THEN -84.38798
		WHEN destination_city = 'Chicago' THEN -87.65005
		WHEN destination_city = 'Dallas' THEN -96.80667
		WHEN destination_city = 'New York' THEN -74.00597
		WHEN destination_city = 'Phoenix' THEN -112.07404
		WHEN destination_city = 'Philadelphia' THEN -75.16362
		WHEN destination_city = 'Houston' THEN -95.36327
		WHEN destination_city = 'Miami' THEN -80.19366
		WHEN destination_city = 'Detroit' THEN -83.04575
		WHEN destination_city = 'Seattle' THEN -122.33207
		WHEN destination_city = 'Denver' THEN -104.9847
		WHEN destination_city = 'Portland' THEN -122.67621
		WHEN destination_city = 'Las Vegas' THEN -115.13722
		WHEN destination_city = 'Minneapolis' THEN -93.26384
		WHEN destination_city = 'Charlotte' THEN -80.84313
		WHEN destination_city = 'Columbus' THEN -82.99879
		WHEN destination_city = 'Memphis' THEN -90.04898
		WHEN destination_city = 'Kansas City' THEN -94.57857
		WHEN destination_city = 'Los Angeles' THEN -118.24368
		WHEN destination_city = 'Indianapolis' THEN -86.15804
	ELSE longitud_destination_city
	END;

--- agregación latitudes de ciudades de destino 

UPDATE routes$
SET latitud_destination_city =
	CASE
		WHEN destination_city = 'Atlanta' THEN 33.749
		WHEN destination_city = 'Chicago' THEN 41.85003
		WHEN destination_city = 'Dallas' THEN 32.78306
		WHEN destination_city = 'New York' THEN 40.71427
		WHEN destination_city = 'Phoenix' THEN 33.44838
		WHEN destination_city = 'Philadelphia' THEN 39.95238 
		WHEN destination_city = 'Houston' THEN 29.76328
		WHEN destination_city = 'Miami' THEN 25.77427
		WHEN destination_city = 'Detroit' THEN 42.33143
		WHEN destination_city = 'Seattle' THEN 47.60621
		WHEN destination_city = 'Denver' THEN 39.73915
		WHEN destination_city = 'Portland' THEN 45.52345
		WHEN destination_city = 'Las Vegas' THEN 36.17497
		WHEN destination_city = 'Minneapolis' THEN 44.97997
		WHEN destination_city = 'Charlotte' THEN 35.22709
		WHEN destination_city = 'Columbus' THEN 39.96118
		WHEN destination_city = 'Memphis' THEN 35.14953
		WHEN destination_city = 'Kansas City' THEN 39.09973
		WHEN destination_city = 'Los Angeles' THEN 34.05223
		WHEN destination_city = 'Indianapolis' THEN 39.76838
	ELSE latitud_destination_city
	END;
```
Paso 4: Creación de vista para comparar entregas retrasadas en la red logística con coordenadas geográficas desde origen-destino

```bash
CREATE OR ALTER VIEW red AS	
WITH conteo_total_viajes AS (
    SELECT 
        r.route_id,
        r.origin_city,
        r.latitud_origin_city,
        r.longitud_origin_city,
        r.destination_city,
        r.latitud_destination_city,
        r.longitud_destination_city,
        COUNT(t.trip_id) AS Qty_trips
    FROM routes$ r
    LEFT JOIN loads$ l ON r.route_id = l.route_id
    LEFT JOIN trips$ t ON l.load_id = t.load_id
    GROUP BY 
        r.route_id, r.origin_city, r.latitud_origin_city, r.longitud_origin_city,
        r.destination_city, r.latitud_destination_city, r.longitud_destination_city
),
promedio_desempeño AS (
    SELECT 
        r.route_id,
        AVG(TRY_CAST(m.on_time_delivery_rate AS numeric(10,4))) AS avg_delivery_rate
    FROM routes$ r
    LEFT JOIN loads$ l ON r.route_id = l.route_id
    LEFT JOIN trips$ t ON l.load_id = t.load_id
    INNER JOIN drivers$ d ON t.driver_id = d.driver_id
    LEFT JOIN driver_monthly_metrics$ m ON d.driver_id = m.driver_id
    GROUP BY r.route_id
)
SELECT 
    c.route_id,
    c.Qty_trips,
    CAST(ISNULL(p.avg_delivery_rate, 0) * c.Qty_trips AS INT) AS on_time_Qty_trips,
    c.Qty_trips - CAST(ISNULL(p.avg_delivery_rate, 0) * c.Qty_trips AS INT) AS late_arrival_Qty_trips,
    c.origin_city,
    c.latitud_origin_city,
    c.longitud_origin_city,
    c.destination_city,
    c.latitud_destination_city,
    c.longitud_destination_city
FROM conteo_total_viajes c
LEFT JOIN promedio_desempeño p ON c.route_id = p.route_id
```

Paso 5: Optimización de las tablas base

```bash
-- Para agilizar el JOIN de 'routes$' con 'loads$'
CREATE INDEX IX_loads_route_id 
ON loads$ (route_id) 
INCLUDE (load_id);

-- Para agilizar el JOIN de 'loads$' con 'trips$' y 'drivers$'
CREATE INDEX IX_trips_load_driver 
ON trips$ (load_id, driver_id) 
INCLUDE (trip_id);

-- Para agilizar el cálculo del promedio del (on_time_delivery_rate) para cada driver_id
CREATE INDEX IX_driver_metrics_performance
ON driver_monthly_metrics$ (driver_id)
INCLUDE (on_time_delivery_rate);

-- Índice de cobertura para la tabla 'routes$'
CREATE INDEX IX_routes_performance 
ON routes$ (route_id) 
INCLUDE (
    origin_city, 
    latitud_origin_city, 
    longitud_origin_city, 
    destination_city, 
    latitud_destination_city, 
    longitud_destination_city
);
```

Paso 6: [Logistic Operations Map](https://public.tableau.com/app/profile/david.santiago.martinez.lopez/viz/LogisticsoperationsMap/Dashboard1)


#### 3. ¿Cuáles fueron los costos ruteados por cantidad de piezas transportadas? Tenga en cuenta la siguiente distribución de los costos: 1. Costo de drivers. 2. Costo de mantenimiento de vehículos. 3. Costo de combustible. 4. Costo de cargue de mercancías.

```bash
```

#### Resultado

```bash
```


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																									
### Customers metrics

#### 1. ¿Cual fue el top 5 de clientes con mayor revenue para la organización?

#### 2. Clasifique los cargues de mercancía que se hicieron por su peso. Aquellas rutas destinadas a un mismo customer_id cuyo peso es <= 15000 lbs es considerado pequeño. Aquellas rutas destinadas a un mismo customer_id cuyo peso es > 15000 lbs y <= 30000 lbs es considerado un cargue medio y los que fueron > 30000 lbs son considerados cargues grandes. ¿Cuales fueron el top 3 de clientes por cada categoría que más viajes se les proveyeron?

#### 3. Ordene de mayor a menor por revenue la cantidad de clientes que en el momento están inactivos o que ya no se les está brindando el servicio de logística. ¿Cuántos viajes se les hicieron a esos clientes en total y cuantos de esos no se lograron cumplir con los tiempos preestablecidos?


