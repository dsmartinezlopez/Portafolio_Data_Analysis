## Proyecto Logistics Operations

Esta es una explicación de paso por paso en MS SQL Server para el desarrollo de este proyecto.

Código completo:

> [!NOTE]
> Si tienes instalado en tu PC MS SQL Server puedes copiar y pegar todo el código completo. Sin embargo, para efectos de organización a continuación se muestra el paso a paso de lo que se realizó.

## Etapa de exploración - preguntas de negocio

### On time delivery metrics

#### 1. Calcule la cantidad de viajes retrasados para cada DRIVER, además devuelva la tasa de retraso en % con 1 decimal. Considere únicamente los DRIVERS que hicieron +700 viajes y genere un ranking por la tasa de retraso y ordénelo de mayor a menor; aquellas tasas de retraso que sean iguales asigneles la misma posición y siga con la siguiente. Calcule además el total de revenue para cada driver.

```bash
SELECT
	driver_id,
	cantidad_viajes,
	NULLIF(CAST(ROUND((tasa_retraso*cantidad_viajes),0) AS int),0) AS cantidad_viajes_retrasados,
	FORMAT(tasa_retraso, 'P1') AS tasa_retraso,
	DENSE_RANK() OVER(ORDER BY tasa_retraso DESC) AS ranking_outliers,
	total_revenue
FROM (
	SELECT 
		driver_id,
		SUM(TRY_CAST(trips_completed AS numeric)) AS cantidad_viajes,
		AVG(TRY_CAST(on_time_delivery_rate AS numeric)) AS tasa_retraso,
		FORMAT(SUM(TRY_CAST(total_revenue AS numeric)), 'C') AS total_revenue
	FROM driver_monthly_metrics$
	GROUP BY driver_id
	HAVING SUM(TRY_CAST(trips_completed AS numeric)) > 700
) AS sub
ORDER BY tasa_retraso DESC
```
#### Resultado

```bash
/*----------+-----------------+----------------------------+--------------+-----------------+---------------+
| driver_id | cantidad_viajes | cantidad_viajes_retrasados | tasa_retraso | ranking_outliers| total_revenue |
+-----------+-----------------+----------------------------+--------------+-----------------+---------------+
| DRV00108  | 735             | 408                        | 55.6%        | 1               | $2,311,329.00 |
| DRV00147  | 705             | 313                        | 44.4%        | 2               | $2,256,066.00 |
| DRV00139  | 710             | 316                        | 44.4%        | 2               | $2,152,412.00 |
| DRV00085  | 703             | 293                        | 41.7%        | 3               | $2,229,522.00 |
| DRV00019  | 749             | 312                        | 41.7%        | 3               | $2,275,651.00 |
| DRV00024  | 708             | 295                        | 41.7%        | 3               | $2,166,574.00 |
| DRV00149  | 721             | 280                        | 38.9%        | 4               | $2,269,105.00 |
| DRV00078  | 717             | 259                        | 36.1%        | 5               | $2,167,291.00 |
| DRV00124  | 702             | 234                        | 33.3%        | 6               | $2,084,929.00 |
| DRV00130  | 701             | 234                        | 33.3%        | 6               | $2,118,376.00 |
| DRV00038  | 705             | 235                        | 33.3%        | 6               | $2,160,496.00 |
| DRV00016  | 712             | 237                        | 33.3%        | 6               | $2,278,576.00 |
| DRV00127  | 702             | 234                        | 33.3%        | 6               | $2,272,321.00 |
| DRV00051  | 723             | 241                        | 33.3%        | 6               | $2,311,845.00 |
| DRV00059  | 729             | 223                        | 30.6%        | 7               | $2,305,055.00 |
| DRV00142  | 711             | 217                        | 30.6%        | 7               | $2,143,054.00 |
| DRV00099  | 711             | 217                        | 30.6%        | 7               | $2,158,400.00 |
| DRV00092  | 711             | 197                        | 27.8%        | 8               | $2,173,931.00 |
| DRV00014  | 707             | 196                        | 27.8%        | 8               | $2,174,425.00 |
| DRV00066  | 737             | 205                        | 27.8%        | 8               | $2,180,636.00 |
| DRV00150  | 706             | 196                        | 27.8%        | 8               | $2,075,242.00 |
| DRV00010  | 709             | 197                        | 27.8%        | 8               | $2,144,656.00 |
| DRV00087  | 725             | 161                        | 22.2%        | 9               | $2,214,001.00 |
+-----------+-----------------+----------------------------+--------------+-----------------+---------------+*/
```

#### 2. ¿Cuáles fueron las marcas de vehículos que más se utilizaron para la realizar los viajes? Muestre la cantidad de viajes realizados y la cantidad de viajes retrasados. Además muestre para cada marca la cantidad de vehículos que estuvieron más de una vez en mantenimiento en un rango de 1 semana y la cantidad de accidentes registrados.


#### 3. ¿Cuales fueron los días de la semana donde más se registraron viajes retrasados? devuelva el resultado en formato de matriz con los días de la semana como columnas y las fechas de los despachos en formato "yyyy-mm" como filas.


#### 4. ¿Cual fue el tiempo promedio (en minutos) de eventos de detención reportados en los viajes para cada ciudad? Muestre el TOP 10 de ciudades con mayores tiempos y compare cuántos de esos eventos de detención terminaron afectando la tasa de cumplimiento.


#### 5. La empresa ha decidido comisionar con 10% (sobre las utilidades) a los DRIVERS (con contrato activo y +5 años de experiencia) que generaron +2M de ingresos para la compañía. ¿Qienes son esos trabajadores y cuánto comisionaron?

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																									
### Logistics network metrics

#### 1. Para cada tipo de facilities ¿cuales fueron el top 5 donde más pasaron los vehículos? Muestre en qué ciudad están ubicados y además calcule dentro de la misma query los subtotales de pedidos que pasaron por cada tipo de facility

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


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
																									
### Customers metrics

#### 1. ¿Cual fue el top 5 de clientes con mayor revenue para la organización?

#### 2. Clasifique los cargues de mercancía que se hicieron por su peso. Aquellas rutas destinadas a un mismo customer_id cuyo peso es <= 15000 lbs es considerado pequeño. Aquellas rutas destinadas a un mismo customer_id cuyo peso es > 15000 lbs y <= 30000 lbs es considerado un cargue medio y los que fueron > 30000 lbs son considerados cargues grandes. ¿Cuales fueron el top 3 de clientes por cada categoría que más viajes se les proveyeron?

#### 3. Ordene de mayor a menor por revenue la cantidad de clientes que en el momento están inactivos o que ya no se les está brindando el servicio de logística. ¿Cuántos viajes se les hicieron a esos clientes en total y cuantos de esos no se lograron cumplir con los tiempos preestablecidos?


