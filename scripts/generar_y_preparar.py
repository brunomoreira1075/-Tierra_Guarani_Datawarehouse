import pandas as pd, numpy as np
from pathlib import Path
R=Path(__file__).resolve().parents[1]; raw=R/'datos_fuente'; out=R/'modelo_powerbi'; raw.mkdir(exist_ok=True);out.mkdir(exist_ok=True)
rng=np.random.default_rng(2026)
prods=pd.DataFrame([{'nk_producto':f'P{i:03}','producto':f'Producto {i:03}','categoria':['Alimentos','Limpieza','Hogar','Bebidas','Higiene'][i%5],'marca':f'Marca {i%9+1}','costo_referencia':int(rng.integers(3500,55000))} for i in range(1,101)])
suc=pd.DataFrame({'nk_sucursal':['S01','S02','S03','S04'],'sucursal':['Casa Central','Sucursal San Lorenzo','Sucursal Luque','Sucursal Fernando de la Mora'],'ciudad':['Asunción','San Lorenzo','Luque','Fernando de la Mora'],'zona':['Centro','Central','Central','Central']})
clientes=pd.DataFrame({'nk_cliente':[f'C{i:04}' for i in range(1,1001)],'segmento':rng.choice(['Frecuente','Ocasional','Nuevo'],1000,p=[.35,.45,.2])})
pagos=pd.DataFrame({'nk_metodo_pago':['EF','TD','TC','TR'],'metodo_pago':['Efectivo','Tarjeta de débito','Tarjeta de crédito','Transferencia']})
prods.to_json(raw/'productos.json',orient='records',force_ascii=False,indent=2)
for name,df in [('productos',prods),('sucursales',suc),('clientes',clientes),('metodos_pago',pagos)]:df.to_csv(raw/f'{name}.csv',index=False,encoding='utf-8-sig')
n=20000; pi=rng.integers(0,len(prods),n); cantidad=rng.integers(1,7,n); costo=prods.costo_referencia.to_numpy()[pi]; precio=np.round(costo*rng.uniform(1.16,1.65,n)/100)*100
fechas=pd.Timestamp('2025-01-01')+pd.to_timedelta(rng.integers(0,730,n),unit='D')
ventas=pd.DataFrame({'nk_linea':[f'L{i:06}' for i in range(1,n+1)],'nk_operacion':[f'T{i//3+1:06}' for i in range(n)],'fecha':fechas.strftime('%Y-%m-%d'),'nk_producto':prods.nk_producto.to_numpy()[pi],'nk_sucursal':rng.choice(suc.nk_sucursal,n),'nk_cliente':rng.choice(clientes.nk_cliente,n),'nk_metodo_pago':rng.choice(pagos.nk_metodo_pago,n),'cantidad':cantidad,'precio_unitario':precio.astype(int),'costo_unitario':costo})
# Defectos reproducibles; mantener las filas originales en staging
ventas.loc[0:19,'nk_producto']='P999';ventas.loc[20:34,'fecha']='fecha_invalida';ventas.loc[35:44,'cantidad']=0;ventas.loc[45:54,'nk_cliente']='';ventas.loc[55:64,'nk_sucursal']='S999';ventas.loc[65:74,'precio_unitario']=-1
ventas=pd.concat([ventas,ventas.iloc[75:85].copy()],ignore_index=True)
ventas.to_csv(raw/'ventas.csv',index=False,encoding='utf-8-sig')
# ETL validado en pandas para entregar CSVs utilizables directamente por Power BI
v=ventas.copy();v['fecha_dt']=pd.to_datetime(v.fecha,errors='coerce');v['nk_cliente']=v.nk_cliente.replace('',pd.NA)
v['motivo_rechazo']='';dupes=v.duplicated('nk_linea',keep='first')
checks=[(dupes,'duplicado_nk_linea'),(v.fecha_dt.isna(),'fecha_invalida'),(v.cantidad<=0,'cantidad_no_positiva'),(v.precio_unitario<=0,'precio_no_positivo'),(~v.nk_producto.isin(prods.nk_producto),'producto_huerfano'),(~v.nk_sucursal.isin(suc.nk_sucursal),'sucursal_huerfana')]
for mask,motivo in checks:v.loc[mask & v.motivo_rechazo.eq(''),'motivo_rechazo']=motivo
rech=v[v.motivo_rechazo.ne('')].copy();rech.drop(columns='fecha_dt').to_csv(out/'rechazos.csv',index=False,encoding='utf-8-sig')
valid=v[v.motivo_rechazo.eq('')].copy();valid['nk_cliente']=valid.nk_cliente.fillna('NO_DEFINIDO')
clientes=pd.concat([pd.DataFrame([{'nk_cliente':'NO_DEFINIDO','segmento':'No definido'}]),clientes],ignore_index=True)
fecha=pd.DataFrame({'fecha':pd.date_range('2025-01-01','2026-12-31')});fecha['sk_fecha']=fecha.fecha.dt.strftime('%Y%m%d').astype(int);fecha['anio']=fecha.fecha.dt.year;fecha['mes']=fecha.fecha.dt.month;fecha['mes_nombre']=fecha.fecha.dt.strftime('%B');fecha['trimestre']=fecha.fecha.dt.quarter;fecha['dia_semana']=fecha.fecha.dt.day_name();fecha['numero_dia_semana']=fecha.fecha.dt.dayofweek+1
fecha['fecha']=fecha.fecha.dt.strftime('%Y-%m-%d')

for name, df, key in [
    ('dim_producto', prods, 'nk_producto'),
    ('dim_sucursal', suc, 'nk_sucursal'),
    ('dim_cliente', clientes, 'nk_cliente'),
    ('dim_metodo_pago', pagos, 'nk_metodo_pago')
]:
    df = df.copy()
    sk_col = 'sk_' + name[4:]

    if name == 'dim_cliente':
        # Cliente desconocido con clave sustituta -1
        df.insert(0, sk_col, [-1] + list(range(1, len(df))))

    elif name == 'dim_producto':
        # SCD Tipo 1: actualizar atributos sin guardar historial
        ruta_anterior = out / 'dim_producto.csv'

        if ruta_anterior.exists():
            anterior = pd.read_csv(
                ruta_anterior,
                encoding='utf-8-sig'
            )

            claves = dict(zip(
                anterior['nk_producto'],
                anterior['sk_producto']
            ))

            siguiente_sk = int(anterior['sk_producto'].max()) + 1
            nuevas_claves = []

            for nk in df['nk_producto']:
                if nk not in claves:
                    claves[nk] = siguiente_sk
                    siguiente_sk += 1

                nuevas_claves.append(claves[nk])

            df.insert(0, sk_col, nuevas_claves)

        else:
            df.insert(
                0,
                sk_col,
                np.arange(1, len(df) + 1)
            )

    else:
        df.insert(
            0,
            sk_col,
            np.arange(1, len(df) + 1)
        )

    # Guardar la dimensión actualizada
    df.to_csv(
        out / (name + '.csv'),
        index=False,
        encoding='utf-8-sig'
    )

    # Conservar las dimensiones para construir la tabla de hechos
    if name == 'dim_producto':
        dp = df

    if name == 'dim_sucursal':
        ds = df

    if name == 'dim_cliente':
        dc = df

    if name == 'dim_metodo_pago':
        dm = df

fecha.to_csv(out/'dim_fecha.csv',index=False,encoding='utf-8-sig')
f=valid.merge(dp[['nk_producto','sk_producto']],on='nk_producto').merge(ds[['nk_sucursal','sk_sucursal']],on='nk_sucursal').merge(dc[['nk_cliente','sk_cliente']],on='nk_cliente').merge(dm[['nk_metodo_pago','sk_metodo_pago']],on='nk_metodo_pago')
f['sk_fecha']=f.fecha_dt.dt.strftime('%Y%m%d').astype(int);f['importe_venta']=f.cantidad*f.precio_unitario;f['costo_total']=f.cantidad*f.costo_unitario;f['margen_bruto']=f.importe_venta-f.costo_total
cols=['nk_linea','nk_operacion','sk_fecha','sk_producto','sk_sucursal','sk_cliente','sk_metodo_pago','cantidad','precio_unitario','costo_unitario','importe_venta','costo_total','margen_bruto']
f[cols].to_csv(out/'fact_ventas.csv',index=False,encoding='utf-8-sig')
res=pd.DataFrame({'motivo':rech.motivo_rechazo.value_counts().index,'registros':rech.motivo_rechazo.value_counts().values});res.to_csv(out/'resumen_calidad.csv',index=False,encoding='utf-8-sig')
print('FUENTE:',len(ventas),'VALIDAS:',len(f),'RECHAZOS:',len(rech));print(res.to_string(index=False));print('IMPORTE TOTAL:',int(f.importe_venta.sum()))
