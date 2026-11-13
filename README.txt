TIERRA GUARANÍ S.R.L. - Proyecto académico ficticio Datawarehouse 2026

1. Instalar Python 3.12, pandas, numpy; ejecutar desde la carpeta del proyecto:
   python scripts/generar_y_preparar.py
2. Instalar DuckDB 1.5 y abrir DBeaver conectado al archivo tierra_guarani.duckdb.
   Ejecutar scripts/modelo_duckdb.sql desde la raíz del proyecto (rutas relativas).
   Ejecutar scripts/consultas_olap.sql.
3. Power BI Desktop: Obtener datos > Texto/CSV; importar los 6 CSV de modelo_powerbi:
   fact_ventas, dim_fecha, dim_producto, dim_sucursal, dim_cliente, dim_metodo_pago.
   Crear relaciones 1:* desde cada dimensión hacia fact_ventas por su sk_*.
   Marcar dim_fecha como tabla de fechas (convertir fecha a tipo Fecha).
   Crear medidas DAX según la guía adjunta.
4. Guardar el archivo .pbix y capturas; crear repositorio Git y hacer commits separados.
5. La presentación PowerPoint contiene resultados ilustrativos calculados sobre los datos sintéticos.

NOTA: La carpeta incluye CSV generados y procesados, scripts y presentación; NO incluye
un archivo .pbix ni repositorio Git remoto, porque requieren Power BI Desktop y cuenta Git.
Los datos no pertenecen a una empresa real.
Fuentes heterogéneas: ventas.csv (CSV) y productos.json (JSON), además de otros CSV.
El SQL de staging extrae productos desde JSON. La versión pandas genera el JSON y
produce el modelo analítico reproducible. La implementación de SCD y el miembro
sk=-1 deben completarse para cumplir literalmente todos los criterios de cátedra.
