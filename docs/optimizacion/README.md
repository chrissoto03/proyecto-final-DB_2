# R4 - Optimización y evidencia

## Estado

La captura de línea base debe ejecutarse en la instancia de SQL Server del equipo antes de crear o modificar índices. El script `database/07_optimization/01_capturar_planes_antes.sql` solo ejecuta consultas existentes, activa el plan real y registra IO/tiempo; no modifica datos ni objetos.

No se deben inventar costos ni declarar optimizaciones como medidas sin conservar los XML de SSMS y los mensajes de `STATISTICS IO/TIME`.

## Captura en SSMS

1. Conecta a `CCC\MSSQLSERVER01` usando autenticación de Windows y selecciona `RentaTicaDB`.
2. Abre el script `database/07_optimization/01_capturar_planes_antes.sql`.
3. Activa **Incluir plan de ejecución real** con `Ctrl+M`.
4. Ejecuta el archivo completo. Guarda cada XML de plan real en `docs/optimizacion/antes/` con estos nombres:
   - `01_inventario_antes.sqlplan` para `renta.usp_Equipo_ListarPorEstado`.
   - `02_reservas_proximas_antes.sqlplan` para `renta.usp_Reserva_Proximas`.
   - `03_ingresos_antes.sqlplan` para `renta.usp_Reporte_IngresosPorDia`.
5. Copia los mensajes de IO y tiempo de cada ejecución a `docs/optimizacion/antes/estadisticas.txt`. Guarda también el `negocio_id` seleccionado y las fechas impresas.
6. Ejecuta el analizador Python descrito abajo para obtener un resumen comparable.

Para guardar un plan en SSMS, selecciona el plan de la consulta correspondiente, clic derecho y **Guardar plan de ejecución como...**. No guardes un solo plan combinado bajo los tres nombres.

## Optimización y captura posterior

Después de revisar los planes y cardinalidades, documenta el diagnóstico y la decisión en `docs/optimizacion/resultado.md`. Solo entonces crea índices u otros cambios justificados, con scripts versionados en `database/07_optimization/` y comentarios sobre sus columnas clave, filtros y consultas que soportan. Evita índices duplicados o recomendaciones automáticas sin validación.

Repite exactamente las mismas consultas, negocio, fechas y estados con `database/07_optimization/02_capturar_planes_despues.sql` cuando ese archivo se prepare tras el análisis. Guarda los XML en `docs/optimizacion/despues/` conservando las etiquetas `01`, `02` y `03`, y agrega IO/tiempo a `docs/optimizacion/despues/estadisticas.txt`. El documento final debe comparar operadores, lecturas lógicas, duración y costo estimado; el costo estimado del plan no representa milisegundos ni una medición de tiempo.

## Analizador de planes

Requisito: Python 3.10 o posterior. Desde Visual Studio, abre una terminal en la raíz del proyecto y ejecuta:

```powershell
python .\tools\analizar_planes.py .\docs\optimizacion\antes .\docs\optimizacion\despues
```

El segundo directorio puede omitirse durante la línea base. El programa genera un resumen de lectura con tablas, operaciones, costos estimados y sugerencias de índices que SQL Server haya incluido en el plan. No crea índices ni cambia SQL.

## Consultas críticas seleccionadas

- `usp_Equipo_ListarPorEstado`: catálogo operativo consultado con frecuencia; une equipos y categorías, restringiendo por negocio y estado.
- `usp_Reserva_Proximas`: agenda próxima; filtra reservas por negocio, estado y fechas, y consulta detalles relacionados.
- `usp_Reporte_IngresosPorDia`: reporte de pagos completados por negocio y periodo, con agregación diaria.

La selección es una hipótesis de trabajo por su función y filtros; el diagnóstico definitivo se basará en los planes capturados y el volumen real de datos.
