
from pathlib import Path
import os
import duckdb

# Carpeta principal del proyecto
PROYECTO = Path(__file__).resolve().parent.parent
os.chdir(PROYECTO)

# Base de datos de pruebas
BASE_DATOS = PROYECTO / "pruebas_ddl" / "tierra_guarani_ejecutor.duckdb"

# Archivos SQL
DDL = PROYECTO / "scripts" / "ddl_datawarehouse.sql"
ETL = PROYECTO / "scripts" / "modelo_duckdb.sql"

conexion = duckdb.connect(str(BASE_DATOS))

try:
    print("Ejecutando DDL...")
    conexion.execute(DDL.read_text(encoding="utf-8"))

    print("Ejecutando ETL...")
    conexion.execute(ETL.read_text(encoding="utf-8"))

    print("Datawarehouse cargado correctamente.")

    # Verificar resultados antes de cerrar la conexion
    resultado = conexion.execute("""
        SELECT
            COUNT(*) AS total_ventas,
            SUM(importe_venta) AS ventas_totales,
            SUM(CASE WHEN sk_cliente = -1 THEN 1 ELSE 0 END)
                AS clientes_desconocidos
        FROM dw.fact_ventas
    """).fetchone()

    print("Total de ventas:", resultado[0])
    print("Ventas totales:", resultado[1])
    print("Clientes desconocidos:", resultado[2])

finally:
    conexion.close()
