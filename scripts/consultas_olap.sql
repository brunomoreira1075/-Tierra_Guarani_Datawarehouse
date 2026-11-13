-- P1 Ventas por sucursal y mes / roll-up
SELECT s.sucursal, t.anio, t.mes, SUM(f.importe_venta) AS ventas_gs
FROM dw.fact_ventas f JOIN dw.dim_sucursal s USING(sk_sucursal) JOIN dw.dim_fecha t USING(sk_fecha)
GROUP BY ROLLUP(s.sucursal,t.anio,t.mes) ORDER BY 1,2,3;
-- P2 Categorías: slice por año
SELECT p.categoria, SUM(f.importe_venta) AS ventas_gs
FROM dw.fact_ventas f JOIN dw.dim_producto p USING(sk_producto) JOIN dw.dim_fecha t USING(sk_fecha)
WHERE t.anio=2026 GROUP BY p.categoria ORDER BY ventas_gs DESC;
-- P3 Ranking de productos / drill-down
SELECT p.categoria,p.producto,SUM(f.cantidad) unidades
FROM dw.fact_ventas f JOIN dw.dim_producto p USING(sk_producto)
GROUP BY p.categoria,p.producto ORDER BY unidades DESC;
-- P4 Margen por categoría y sucursal / dice
SELECT p.categoria,s.sucursal,SUM(f.margen_bruto) margen_gs,
ROUND(100*SUM(f.margen_bruto)/NULLIF(SUM(f.importe_venta),0),2) margen_pct
FROM dw.fact_ventas f JOIN dw.dim_producto p USING(sk_producto) JOIN dw.dim_sucursal s USING(sk_sucursal)
GROUP BY GROUPING SETS ((p.categoria,s.sucursal),(p.categoria),()) ORDER BY 1,2;
-- P5 Variación mensual / pivot temporal
WITH m AS (SELECT t.anio,t.mes,SUM(f.importe_venta) ventas FROM dw.fact_ventas f JOIN dw.dim_fecha t USING(sk_fecha) GROUP BY 1,2)
SELECT *,ROUND(100*(ventas-LAG(ventas) OVER(ORDER BY anio,mes))/NULLIF(LAG(ventas) OVER(ORDER BY anio,mes),0),2) variacion_pct FROM m ORDER BY 1,2;
-- P6 Día de semana: conteo de operaciones distintas
SELECT t.dia_semana,COUNT(DISTINCT f.nk_operacion) operaciones,SUM(f.importe_venta) ventas_gs
FROM dw.fact_ventas f JOIN dw.dim_fecha t USING(sk_fecha) GROUP BY 1 ORDER BY ventas_gs DESC;
-- P7 Ticket promedio por sucursal: suma de ventas / tickets únicos
SELECT s.sucursal,ROUND(SUM(f.importe_venta)/NULLIF(COUNT(DISTINCT f.nk_operacion),0),0) ticket_promedio_gs
FROM dw.fact_ventas f JOIN dw.dim_sucursal s USING(sk_sucursal) GROUP BY 1;
-- P8 Medio de pago / CUBE
SELECT p.metodo_pago,s.sucursal,COUNT(DISTINCT f.nk_operacion) operaciones,SUM(f.importe_venta) ventas_gs
FROM dw.fact_ventas f JOIN dw.dim_metodo_pago p USING(sk_metodo_pago) JOIN dw.dim_sucursal s USING(sk_sucursal)
GROUP BY CUBE(p.metodo_pago,s.sucursal) ORDER BY 1,2;
