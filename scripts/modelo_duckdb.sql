
-- ============================================================
-- TIERRA GUARANI S.R.L.
-- DATAWAREHOUSE - ETL CON SCD TIPO 1
-- ============================================================

-- REQUISITOS:
-- 1. Ejecutar previamente ddl_datawarehouse.sql.
-- 2. Ejecutar desde la carpeta principal del proyecto.
-- 3. Utilizar ejecutar_datawarehouse.py.
--
-- El script conserva las claves primarias y foraneas.
-- Las rutas son relativas para facilitar su portabilidad.

-- ============================================================
-- 1. CREAR ESQUEMAS
-- ============================================================

CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS stg;


-- ============================================================
-- 2. CARGAR DATOS DE ORIGEN EN STAGING
-- ============================================================

-- Ventas desde CSV
CREATE OR REPLACE TABLE stg.ventas AS
SELECT *
FROM read_csv_auto(
    'datos_fuente/ventas.csv',
    all_varchar = true
);

-- Productos desde JSON
CREATE OR REPLACE TABLE stg.productos AS
SELECT *
FROM read_json_auto(
    'datos_fuente/productos.json'
);

-- Sucursales desde CSV
CREATE OR REPLACE TABLE stg.sucursales AS
SELECT *
FROM read_csv_auto(
    'datos_fuente/sucursales.csv'
);

-- Clientes desde CSV
CREATE OR REPLACE TABLE stg.clientes AS
SELECT *
FROM read_csv_auto(
    'datos_fuente/clientes.csv'
);

-- Metodos de pago desde CSV
CREATE OR REPLACE TABLE stg.metodos_pago AS
SELECT *
FROM read_csv_auto(
    'datos_fuente/metodos_pago.csv'
);


-- ============================================================
-- 3. CARGAR DIMENSION CLIENTE
-- ============================================================

-- El cliente desconocido utiliza sk_cliente = -1.
-- Se evita duplicar clientes existentes.

INSERT INTO dw.dim_cliente
SELECT *
FROM read_csv_auto(
    'modelo_powerbi/dim_cliente.csv'
)
ON CONFLICT (sk_cliente) DO NOTHING;


-- ============================================================
-- 4. CARGAR DIMENSION PRODUCTO
-- ============================================================

-- Insertar productos nuevos sin duplicar claves.

INSERT INTO dw.dim_producto
SELECT *
FROM read_csv_auto(
    'modelo_powerbi/dim_producto.csv'
)
ON CONFLICT (sk_producto) DO NOTHING;


-- SCD TIPO 1
-- Actualizar los atributos que cambiaron.
-- Se conserva la clave sustituta sk_producto.
-- No se modifica el historial de ventas.

UPDATE dw.dim_producto AS p
SET
    producto = csv.producto,
    categoria = csv.categoria,
    marca = csv.marca,
    costo_referencia = csv.costo_referencia
FROM read_csv_auto(
    'modelo_powerbi/dim_producto.csv'
) AS csv
WHERE p.sk_producto = csv.sk_producto
  AND (
      p.producto IS DISTINCT FROM csv.producto
      OR p.categoria IS DISTINCT FROM csv.categoria
      OR p.marca IS DISTINCT FROM csv.marca
      OR p.costo_referencia IS DISTINCT FROM csv.costo_referencia
  );


-- ============================================================
-- 5. CARGAR DIMENSION SUCURSAL
-- ============================================================

INSERT INTO dw.dim_sucursal
SELECT *
FROM read_csv_auto(
    'modelo_powerbi/dim_sucursal.csv'
)
ON CONFLICT (sk_sucursal) DO NOTHING;


-- ============================================================
-- 6. CARGAR DIMENSION FECHA
-- ============================================================

INSERT INTO dw.dim_fecha
SELECT *
FROM read_csv_auto(
    'modelo_powerbi/dim_fecha.csv'
)
ON CONFLICT (sk_fecha) DO NOTHING;


-- ============================================================
-- 7. CARGAR DIMENSION METODO DE PAGO
-- ============================================================

INSERT INTO dw.dim_metodo_pago
SELECT *
FROM read_csv_auto(
    'modelo_powerbi/dim_metodo_pago.csv'
)
ON CONFLICT (sk_metodo_pago) DO NOTHING;


-- ============================================================
-- 8. CARGAR TABLA DE HECHOS
-- ============================================================

-- Las dimensiones se cargan antes que las ventas.
-- Se respetan las cinco claves foraneas.
-- No se duplican lineas de venta.

INSERT INTO dw.fact_ventas
SELECT *
FROM read_csv_auto(
    'modelo_powerbi/fact_ventas.csv'
)
ON CONFLICT (nk_linea) DO NOTHING;


-- ============================================================
-- 9. CARGAR REGISTROS RECHAZADOS
-- ============================================================

CREATE OR REPLACE TABLE dw.rechazos AS
SELECT *
FROM read_csv_auto(
    'modelo_powerbi/rechazos.csv',
    all_varchar = true
);


-- ============================================================
-- 10. VERIFICAR CANTIDAD DE REGISTROS
-- ============================================================

SELECT 'dim_cliente' AS tabla, COUNT(*) AS registros
FROM dw.dim_cliente

UNION ALL
SELECT 'dim_producto', COUNT(*) FROM dw.dim_producto

UNION ALL
SELECT 'dim_sucursal', COUNT(*) FROM dw.dim_sucursal

UNION ALL
SELECT 'dim_fecha', COUNT(*) FROM dw.dim_fecha

UNION ALL
SELECT 'dim_metodo_pago', COUNT(*) FROM dw.dim_metodo_pago

UNION ALL
SELECT 'fact_ventas', COUNT(*) FROM dw.fact_ventas

UNION ALL
SELECT 'rechazos', COUNT(*) FROM dw.rechazos;


-- ============================================================
-- 11. VERIFICAR VENTAS TOTALES
-- ============================================================

SELECT
    COUNT(*) AS total_ventas,
    SUM(importe_venta) AS ventas_totales,
    SUM(
        CASE WHEN sk_cliente = -1 THEN 1 ELSE 0 END
    ) AS clientes_desconocidos
FROM dw.fact_ventas;


-- ============================================================
-- 12. VERIFICAR INTEGRIDAD REFERENCIAL
-- ============================================================

SELECT COUNT(*) AS ventas_sin_cliente_valido
FROM dw.fact_ventas f
LEFT JOIN dw.dim_cliente c
    ON f.sk_cliente = c.sk_cliente
WHERE c.sk_cliente IS NULL;


-- ============================================================
-- 13. DETECTAR CAMBIOS PENDIENTES EN PRODUCTOS
-- ============================================================

-- Despues del UPDATE SCD Tipo 1, normalmente
-- no deberian quedar diferencias con el CSV.

SELECT
    p.sk_producto,
    p.producto AS producto_actual,
    csv.producto AS producto_nuevo,
    p.categoria AS categoria_actual,
    csv.categoria AS categoria_nueva,
    p.marca AS marca_actual,
    csv.marca AS marca_nueva,
    p.costo_referencia AS costo_actual,
    csv.costo_referencia AS costo_nuevo
FROM dw.dim_producto p
JOIN read_csv_auto(
    'modelo_powerbi/dim_producto.csv'
) AS csv
    ON p.sk_producto = csv.sk_producto
WHERE
    p.producto IS DISTINCT FROM csv.producto
    OR p.categoria IS DISTINCT FROM csv.categoria
    OR p.marca IS DISTINCT FROM csv.marca
    OR p.costo_referencia IS DISTINCT FROM csv.costo_referencia;
