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

#### 2. Cree una tabla con las rutas asignadas de ciudades desde origen a destino. Contemple todos los facilities de la red logística por los que pasaron los vehículos y compare la cantidad de viajes retrasados. Muestre el diseño de la red en un Dashboard. 


#### 3. ¿Cuáles fueron los costos ruteados por cantidad de piezas transportadas? Tenga en cuenta la siguiente distribución de los costos: 1. Costo de drivers. 2. Costo de mantenimiento de vehículos. 3. Costo de combustible. 4. Costo de cargue de mercancías.




