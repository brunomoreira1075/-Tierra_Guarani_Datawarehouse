
-- ============================================================
-- TIERRA GUARANI S.R.L.
-- CONSULTAS OLAP DEL DATAWAREHOUSE
-- ============================================================

-- P1. VENTAS POR SUCURSAL, ANIO Y MES - ROLLUP

SELECT
    CASE
        WHEN GROUPING(s.sucursal) = 1 THEN 'TOTAL GENERAL'
        ELSE s.sucursal
    END AS sucursal,
    t.anio,
    t.mes,
    SUM(f.importe_venta) AS ventas_gs
FROM dw.fact_ventas f
JOIN dw.dim_sucursal s USING (sk_sucursal)
JOIN dw.dim_fecha t USING (sk_fecha)
GROUP BY ROLLUP(s.sucursal, t.anio, t.mes)
ORDER BY
    GROUPING(s.sucursal), s.sucursal,
    GROUPING(t.anio), t.anio,
    GROUPING(t.mes), t.mes;


-- ============================================================
-- P2. VENTAS POR CATEGORIA - SLICE POR ANIO
-- ============================================================

SELECT
    t.anio,
    p.categoria,
    SUM(f.importe_venta) AS ventas_gs,
    SUM(f.cantidad) AS unidades_vendidas
FROM dw.fact_ventas f
JOIN dw.dim_producto p USING (sk_producto)
JOIN dw.dim_fecha t USING (sk_fecha)
WHERE t.anio = 2026
GROUP BY t.anio, p.categoria
ORDER BY ventas_gs DESC;


-- ============================================================
-- P3. RANKING DE PRODUCTOS - DRILL DOWN
-- ============================================================

SELECT
    p.categoria,
    p.producto,
    SUM(f.cantidad) AS unidades_vendidas,
    SUM(f.importe_venta) AS ventas_gs,
    SUM(f.margen_bruto) AS margen_gs
FROM dw.fact_ventas f
JOIN dw.dim_producto p USING (sk_producto)
GROUP BY p.categoria, p.producto
ORDER BY unidades_vendidas DESC, ventas_gs DESC;


-- ============================================================
-- P4. MARGEN POR CATEGORIA Y SUCURSAL - GROUPING SETS
-- ============================================================

SELECT
    CASE
        WHEN GROUPING(p.categoria) = 1 THEN 'TOTAL GENERAL'
        ELSE p.categoria
    END AS categoria,

    CASE
        WHEN GROUPING(s.sucursal) = 1 THEN 'TODAS LAS SUCURSALES'
        ELSE s.sucursal
    END AS sucursal,

    SUM(f.importe_venta) AS ventas_gs,
    SUM(f.margen_bruto) AS margen_gs,

    ROUND(
        100.0 * SUM(f.margen_bruto)
        / NULLIF(SUM(f.importe_venta), 0),
        2
    ) AS margen_pct

FROM dw.fact_ventas f
JOIN dw.dim_producto p USING (sk_producto)
JOIN dw.dim_sucursal s USING (sk_sucursal)

GROUP BY GROUPING SETS (
    (p.categoria, s.sucursal),
    (p.categoria),
    ()
)

ORDER BY
    GROUPING(p.categoria),
    p.categoria,
    GROUPING(s.sucursal),
    s.sucursal;


-- ============================================================
-- P5. VARIACION MENSUAL DE VENTAS - ANALISIS TEMPORAL
-- ============================================================

WITH ventas_mensuales AS (
    SELECT
        t.anio,
        t.mes,
        SUM(f.importe_venta) AS ventas_gs
    FROM dw.fact_ventas f
    JOIN dw.dim_fecha t USING (sk_fecha)
    GROUP BY t.anio, t.mes
),

comparacion AS (
    SELECT
        anio,
        mes,
        ventas_gs,
        LAG(ventas_gs) OVER (
            ORDER BY anio, mes
        ) AS ventas_mes_anterior
    FROM ventas_mensuales
)

SELECT
    anio,
    mes,
    ventas_gs,
    ventas_mes_anterior,
    ROUND(
        100.0 * (ventas_gs - ventas_mes_anterior)
        / NULLIF(ventas_mes_anterior, 0),
        2
    ) AS variacion_pct
FROM comparacion
ORDER BY anio, mes;


-- ============================================================
-- P6. VENTAS POR DIA DE LA SEMANA
-- ============================================================

SELECT
    t.numero_dia_semana,
    t.dia_semana,
    COUNT(DISTINCT f.nk_operacion) AS operaciones,
    SUM(f.cantidad) AS unidades_vendidas,
    SUM(f.importe_venta) AS ventas_gs
FROM dw.fact_ventas f
JOIN dw.dim_fecha t USING (sk_fecha)
GROUP BY t.numero_dia_semana, t.dia_semana
ORDER BY t.numero_dia_semana;


-- ============================================================
-- P7. TICKET PROMEDIO POR SUCURSAL
-- ============================================================

WITH tickets AS (
    SELECT
        f.sk_sucursal,
        f.nk_operacion,
        SUM(f.importe_venta) AS importe_ticket
    FROM dw.fact_ventas f
    GROUP BY f.sk_sucursal, f.nk_operacion
)

SELECT
    s.sucursal,
    COUNT(*) AS cantidad_tickets,
    SUM(t.importe_ticket) AS ventas_gs,
    ROUND(AVG(t.importe_ticket), 0) AS ticket_promedio_gs
FROM tickets t
JOIN dw.dim_sucursal s USING (sk_sucursal)
GROUP BY s.sucursal
ORDER BY ticket_promedio_gs DESC;


-- ============================================================
-- P8. MEDIOS DE PAGO Y SUCURSALES - CUBE
-- ============================================================

SELECT
    CASE
        WHEN GROUPING(p.metodo_pago) = 1 THEN 'TODOS LOS METODOS'
        ELSE p.metodo_pago
    END AS metodo_pago,

    CASE
        WHEN GROUPING(s.sucursal) = 1 THEN 'TODAS LAS SUCURSALES'
        ELSE s.sucursal
    END AS sucursal,

    COUNT(DISTINCT f.nk_operacion) AS operaciones,
    SUM(f.importe_venta) AS ventas_gs

FROM dw.fact_ventas f
JOIN dw.dim_metodo_pago p USING (sk_metodo_pago)
JOIN dw.dim_sucursal s USING (sk_sucursal)

GROUP BY CUBE(p.metodo_pago, s.sucursal)

ORDER BY
    GROUPING(p.metodo_pago),
    p.metodo_pago,
    GROUPING(s.sucursal),
    s.sucursal;


-- ============================================================
-- P9. VALIDACION FINAL DEL DATAWAREHOUSE
-- ============================================================

SELECT
    COUNT(*) AS lineas_validas,
    SUM(importe_venta) AS ventas_totales_gs,
    SUM(cantidad) AS unidades_totales,
    SUM(margen_bruto) AS margen_total_gs,
    COUNT(DISTINCT nk_operacion) AS operaciones_distintas,
    SUM(
        CASE WHEN sk_cliente = -1 THEN 1 ELSE 0 END
    ) AS ventas_cliente_desconocido
FROM dw.fact_ventas;


-- ============================================================
-- P10. VALIDACION DE RECHAZOS
-- ============================================================

SELECT
    COUNT(*) AS registros_rechazados
FROM dw.rechazos;
