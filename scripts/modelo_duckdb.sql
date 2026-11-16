
-- ============================================================
-- TIERRA GUARANI S.R.L.
-- CARGA DEL DATAWAREHOUSE - DUCKDB
-- ============================================================

-- IMPORTANTE:
-- Ejecutar primero scripts/ddl_datawarehouse.sql
-- para crear las tablas con claves primarias y foraneas.
--
-- Este script carga los datos sin reemplazar las tablas
-- dimensionales ni la tabla de hechos.

-- 1. CREAR ESQUEMAS
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS stg;


-- ============================================================
-- 2. CARGAR DATOS DE ORIGEN EN STAGING
-- ============================================================

-- Ventas (CSV)
CREATE OR REPLACE TABLE stg.ventas AS
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/datos_fuente/ventas.csv',
    all_varchar = true
);

-- Productos (JSON)
CREATE OR REPLACE TABLE stg.productos AS
SELECT *
FROM read_json_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/datos_fuente/productos.json'
);

-- Sucursales (CSV)
CREATE OR REPLACE TABLE stg.sucursales AS
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/datos_fuente/sucursales.csv'
);

-- Clientes (CSV)
CREATE OR REPLACE TABLE stg.clientes AS
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/datos_fuente/clientes.csv'
);

-- Metodos de pago (CSV)
CREATE OR REPLACE TABLE stg.metodos_pago AS
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/datos_fuente/metodos_pago.csv'
);


-- ============================================================
-- 3. CARGAR DIMENSIONES
-- ============================================================

-- DIMENSION CLIENTE
-- Incluye el cliente desconocido con sk_cliente = -1.

INSERT INTO dw.dim_cliente
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/modelo_powerbi/dim_cliente.csv'
)
ON CONFLICT (sk_cliente) DO NOTHING;


-- DIMENSION PRODUCTO
-- SCD Tipo 1: actualiza atributos sin cambiar sk_producto.

INSERT INTO dw.dim_producto
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/modelo_powerbi/dim_producto.csv'
)
ON CONFLICT (sk_producto) DO UPDATE SET
    nk_producto = EXCLUDED.nk_producto,
    producto = EXCLUDED.producto,
    categoria = EXCLUDED.categoria,
    marca = EXCLUDED.marca,
    costo_referencia = EXCLUDED.costo_referencia;


-- DIMENSION SUCURSAL

INSERT INTO dw.dim_sucursal
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/modelo_powerbi/dim_sucursal.csv'
)
ON CONFLICT (sk_sucursal) DO NOTHING;


-- DIMENSION FECHA

INSERT INTO dw.dim_fecha
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/modelo_powerbi/dim_fecha.csv'
)
ON CONFLICT (sk_fecha) DO NOTHING;


-- DIMENSION METODO DE PAGO

INSERT INTO dw.dim_metodo_pago
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/modelo_powerbi/dim_metodo_pago.csv'
)
ON CONFLICT (sk_metodo_pago) DO NOTHING;


-- ============================================================
-- 4. CARGAR TABLA DE HECHOS
-- ============================================================

-- Las dimensiones deben estar cargadas antes que las ventas.
-- Las claves foraneas se validan automaticamente.
-- ON CONFLICT evita duplicar lineas de venta.

INSERT INTO dw.fact_ventas
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/modelo_powerbi/fact_ventas.csv'
)
ON CONFLICT (nk_linea) DO NOTHING;


-- ============================================================
-- 5. CARGAR REGISTROS RECHAZADOS
-- ============================================================

CREATE OR REPLACE TABLE dw.rechazos AS
SELECT *
FROM read_csv_auto(
    'C:/Users/bruno/Downloads/Tierra_Guarani_Proyecto_Completo/Tierra_Guarani_Proyecto/modelo_powerbi/rechazos.csv',
    all_varchar = true
);


-- ============================================================
-- 6. VERIFICACIONES
-- ============================================================

-- Cantidad de registros por tabla

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


-- Total de ventas

SELECT
    COUNT(*) AS lineas_validas,
    SUM(importe_venta) AS ventas_gs
FROM dw.fact_ventas;


-- Ventas con cliente desconocido

SELECT COUNT(*) AS clientes_desconocidos
FROM dw.fact_ventas
WHERE sk_cliente = -1;


-- Comprobar integridad referencial de clientes

SELECT COUNT(*) AS ventas_sin_cliente_valido
FROM dw.fact_ventas f
LEFT JOIN dw.dim_cliente c
    ON f.sk_cliente = c.sk_cliente
WHERE c.sk_cliente IS NULL;
