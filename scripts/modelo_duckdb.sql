-- Ejecutar en DuckDB 1.5; rutas CSV relativas al directorio del proyecto.
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE OR REPLACE TABLE stg.ventas AS SELECT * FROM read_csv_auto('datos_fuente/ventas.csv', all_varchar=true);
CREATE OR REPLACE TABLE stg.productos AS SELECT * FROM read_json_auto('datos_fuente/productos.json');
CREATE OR REPLACE TABLE stg.sucursales AS SELECT * FROM read_csv_auto('datos_fuente/sucursales.csv');
CREATE OR REPLACE TABLE stg.clientes AS SELECT * FROM read_csv_auto('datos_fuente/clientes.csv');
CREATE OR REPLACE TABLE stg.metodos_pago AS SELECT * FROM read_csv_auto('datos_fuente/metodos_pago.csv');
-- CSV dimensionales producidos por el ETL reproducible en scripts/generar_y_preparar.py
CREATE OR REPLACE TABLE dw.dim_fecha AS SELECT * FROM read_csv_auto('modelo_powerbi/dim_fecha.csv');
CREATE OR REPLACE TABLE dw.dim_producto AS SELECT * FROM read_csv_auto('modelo_powerbi/dim_producto.csv');
CREATE OR REPLACE TABLE dw.dim_sucursal AS SELECT * FROM read_csv_auto('modelo_powerbi/dim_sucursal.csv');
CREATE OR REPLACE TABLE dw.dim_cliente AS SELECT * FROM read_csv_auto('modelo_powerbi/dim_cliente.csv');
CREATE OR REPLACE TABLE dw.dim_metodo_pago AS SELECT * FROM read_csv_auto('modelo_powerbi/dim_metodo_pago.csv');
CREATE OR REPLACE TABLE dw.fact_ventas AS SELECT * FROM read_csv_auto('modelo_powerbi/fact_ventas.csv');
CREATE OR REPLACE TABLE dw.rechazos AS SELECT * FROM read_csv_auto('modelo_powerbi/rechazos.csv',all_varchar=true);
-- El cliente desconocido utiliza la clave sustituta -1.
-- El ETL genera esta clave en dim_cliente y fact_ventas.
SELECT COUNT(*) AS lineas_validas, SUM(importe_venta) AS ventas_gs FROM dw.fact_ventas;
