
from pathlib import Path
import os
import duckdb

# ============================================================
# TIERRA GUARANI S.R.L.
# PRUEBA REAL DE SCD TIPO 1
# ============================================================

PROYECTO = Path(__file__).resolve().parent.parent
os.chdir(PROYECTO)

BASE_DATOS = (
    PROYECTO
    / "pruebas_ddl"
    / "tierra_guarani_ejecutor.duckdb"
)

CSV_PRODUCTOS = PROYECTO / "modelo_powerbi" / "dim_producto.csv"

conexion = duckdb.connect(str(BASE_DATOS))

try:
    # ========================================================
    # 1. CONSULTAR PRODUCTO ORIGINAL
    # ========================================================

    producto_original = conexion.execute("""
        SELECT sk_producto, nk_producto, producto, categoria
        FROM dw.dim_producto
        WHERE sk_producto = 1
    """).fetchone()

    ventas_originales = conexion.execute("""
        SELECT COUNT(*)
        FROM dw.fact_ventas
        WHERE sk_producto = 1
    """).fetchone()[0]

    print("Producto original:", producto_original)
    print("Ventas relacionadas:", ventas_originales)

    # ========================================================
    # 2. CREAR UNA FUENTE TEMPORAL CON UN CAMBIO
    # ========================================================

    # No modificamos el CSV original.
    conexion.execute("""
        CREATE TEMP TABLE productos_prueba AS
        SELECT
            sk_producto,
            nk_producto,
            CASE
                WHEN sk_producto = 1
                THEN 'Producto 001 Actualizado'
                ELSE producto
            END AS producto,
            categoria,
            marca,
            costo_referencia
        FROM read_csv_auto(?)
    """, [str(CSV_PRODUCTOS)])

    # ========================================================
    # 3. INICIAR TRANSACCION
    # ========================================================

    conexion.execute("BEGIN TRANSACTION")

    try:
        # Aplicar SCD Tipo 1 con UPDATE FROM
        conexion.execute("""
            UPDATE dw.dim_producto AS p
            SET
                producto = csv.producto,
                categoria = csv.categoria,
                marca = csv.marca,
                costo_referencia = csv.costo_referencia
            FROM productos_prueba AS csv
            WHERE p.sk_producto = csv.sk_producto
              AND (
                  p.producto IS DISTINCT FROM csv.producto
                  OR p.categoria IS DISTINCT FROM csv.categoria
                  OR p.marca IS DISTINCT FROM csv.marca
                  OR p.costo_referencia
                     IS DISTINCT FROM csv.costo_referencia
              )
        """)

        # ====================================================
        # 4. COMPROBAR LA ACTUALIZACION
        # ====================================================

        producto_actualizado = conexion.execute("""
            SELECT sk_producto, nk_producto, producto, categoria
            FROM dw.dim_producto
            WHERE sk_producto = 1
        """).fetchone()

        ventas_actualizadas = conexion.execute("""
            SELECT COUNT(*)
            FROM dw.fact_ventas
            WHERE sk_producto = 1
        """).fetchone()[0]

        print("Producto actualizado:", producto_actualizado)
        print("Ventas despues del cambio:", ventas_actualizadas)

        assert producto_actualizado[0] == 1
        assert producto_actualizado[1] == "P001"
        assert producto_actualizado[2] == "Producto 001 Actualizado"
        assert ventas_actualizadas == ventas_originales

        print("PRUEBA SCD TIPO 1: CORRECTA")

    finally:
        # ====================================================
        # 5. REVERTIR CAMBIOS
        # ====================================================

        conexion.execute("ROLLBACK")
        print("Cambios revertidos correctamente.")

    # ========================================================
    # 6. COMPROBAR ESTADO FINAL
    # ========================================================

    producto_final = conexion.execute("""
        SELECT sk_producto, nk_producto, producto, categoria
        FROM dw.dim_producto
        WHERE sk_producto = 1
    """).fetchone()

    ventas_finales = conexion.execute("""
        SELECT COUNT(*)
        FROM dw.fact_ventas
        WHERE sk_producto = 1
    """).fetchone()[0]

    print("Producto final:", producto_final)
    print("Ventas finales:", ventas_finales)

    assert producto_final == producto_original
    assert ventas_finales == ventas_originales

    print("BASE DE DATOS CONSERVADA CORRECTAMENTE")

finally:
    conexion.close()
