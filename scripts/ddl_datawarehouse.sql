-- DDL explícito del Datawarehouse Tierra Guaraní
-- Definición de la tabla de hechos de ventas

CREATE SCHEMA IF NOT EXISTS dw;

CREATE TABLE IF NOT EXISTS dw.fact_ventas (
    nk_linea VARCHAR PRIMARY KEY,
    nk_operacion VARCHAR,
    sk_fecha BIGINT,
    sk_producto BIGINT,
    sk_sucursal BIGINT,
    sk_cliente BIGINT,
    sk_metodo_pago BIGINT,
    cantidad BIGINT,
    precio_unitario BIGINT,
    costo_unitario BIGINT,
    importe_venta BIGINT,
    costo_total BIGINT,
    margen_bruto BIGINT
);
-- Dimension de clientes
-- Incluye el cliente desconocido con sk_cliente = -1

CREATE TABLE IF NOT EXISTS dw.dim_cliente (
    sk_cliente BIGINT PRIMARY KEY,
    nk_cliente VARCHAR NOT NULL,
    segmento VARCHAR
);
-- Dimension de productos
-- La clave sustituta se conserva durante las actualizaciones SCD Tipo 1

CREATE TABLE IF NOT EXISTS dw.dim_producto (
    sk_producto BIGINT PRIMARY KEY,
    nk_producto VARCHAR NOT NULL UNIQUE,
    producto VARCHAR NOT NULL,
    categoria VARCHAR,
    marca VARCHAR,
    costo_referencia BIGINT
);
-- Dimension de sucursales

CREATE TABLE IF NOT EXISTS dw.dim_sucursal (
    sk_sucursal BIGINT PRIMARY KEY,
    nk_sucursal VARCHAR NOT NULL UNIQUE,
    sucursal VARCHAR NOT NULL,
    ciudad VARCHAR,
    zona VARCHAR
);
-- Dimension de fechas
-- Permite analizar ventas por dia, mes, trimestre y anio

CREATE TABLE IF NOT EXISTS dw.dim_fecha (
    fecha DATE NOT NULL UNIQUE,
    sk_fecha BIGINT PRIMARY KEY,
    anio BIGINT NOT NULL,
    mes BIGINT NOT NULL,
    mes_nombre VARCHAR,
    trimestre BIGINT,
    dia_semana VARCHAR,
    numero_dia_semana BIGINT
);
-- Dimension de metodos de pago

CREATE TABLE IF NOT EXISTS dw.dim_metodo_pago (
    sk_metodo_pago BIGINT PRIMARY KEY,
    nk_metodo_pago VARCHAR NOT NULL UNIQUE,
    metodo_pago VARCHAR NOT NULL
);