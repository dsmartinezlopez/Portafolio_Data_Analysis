## Proyecto Brazilian E-commerce

Esta es una explicación de paso por paso en MS SQL Server para el desarrollo de este proyecto.

Código completo: [E-commerce Brazil](https://github.com/dsmartinezlopez/Portafolio_Data_Analysis/blob/Portafolio-projects-1/SQLQueryProyectoEcommerceBrazil.sql)

> [!NOTE]
> Si tienes instalado en tu PC MS SQL Server puedes copiar y pegar todo el código completo. Sin embargo, para efectos de organización a continuación se muestra el paso a paso de lo que se realizó.


## Etapa de exploración - preguntas de negocio

## Análisis con visión operativa

#### 1. ¿Cuál fue el volumen de pedidos enviados y cuántos cumplieron el tiempo de entrega y cuántos no?
#### 2. ¿Cuál es el GAP de incumplimiento de entregas comparando MoM (Month-over-Month) de cada año?
#### 3. Si la clasificación de los productos se establece de acuerdo al peso, donde SMALL se denomina todo lo que pese <= 1000 gramos, MEDIUM todo lo que pese > 1000 gramos y <= 10000 gramos, y BIG todo lo que pese > 10000 gramos ¿cuales fueron las clasificaciones que más porcentaje de incumplimiento tuvieron ordenadas de forma descendente?
#### 4. ¿Cuál fue el TOP 5 de órdenes_id enviadas que más se demoraron en completarse? muestre id de la orden, producto(s), ciudad origen (vendedor), ciudad destino (comprador) y cantidad de días transcurridos desde la fecha de compra y la fecha de entrega. 

-----------------------------------------------------------------------------------------------------------------------------------------------------------

## Análisis con visión de negocio/revenue

### Ingresos

#### 1. ¿Cuál fue la suma del total de pagos que se cerró al primer día de cada mes? muestre el total acumulado de los pagos MoM (Month-over-Month)

```bash
```

#### 2. ¿Cómo fue la distribución de los medios de pago para cada categoría de productos? muestre la composición porcentual para cada medio de pago por estado/provincia

### Utilidades

#### 1. ¿Cuáles fueron el TOP 3 de ciudades por cada estado que más utilidades obtuvieron? 

### Flujo de caja

#### 1. ¿Con qué medio de pago se registró la compra más alta que se pagó de contado y en qué fecha se ejecutó la compra? 
#### 2. ¿Cuál fue el TOP 5 de vendedores que más flujo de caja obtuvieron de sus ventas? 

