# R4 - Optimización y evidencia

## Estado

La captura de línea base debe ejecutarse en la instancia de SQL Server del equipo antes de crear o modificar índices. El script `database/07_optimization/01_capturar_planes_antes.sql` solo ejecuta consultas existentes y registra IO/tiempo; no modifica datos ni objetos. Activa el plan real desde SSMS con `Ctrl+M`.

No se deben inventar costos ni declarar optimizaciones como medidas sin conservar los XML de SSMS y los mensajes de `STATISTICS IO/TIME`.

## Captura en SSMS

1. Conecta a `CCC\MSSQLSERVER01` usando autenticación de Windows y selecciona `RentaTicaDB`.
2. Ejecuta una sola vez `database/05_tests/11_preparar_escenario_rendimiento.sql`. Crea un negocio temporal aislado con 250 equipos, 40 reservas y 40 pagos. Si lo ejecutas de nuevo, reemplaza solo su propio escenario; no lo repitas entre capturas.
3. Abre el script `database/07_optimization/01_capturar_planes_antes.sql`.
4. Activa **Incluir plan de ejecución real** con `Ctrl+M`.
5. Ejecuta el archivo completo. Para guardar el plan combinado, clic derecho en el diagrama de **Plan de ejecución** y guarda como `docs/optimizacion/antes/00_linea_base_completa.sqlplan`.
6. Copia los mensajes de IO y tiempo a `docs/optimizacion/antes/estadisticas.txt`. Conserva el `negocio_id` y el rango de fechas que devuelve el SELECT de parámetros.
## Optimización y captura posterior

El análisis del plan base quedó en `docs/optimizacion/resultado.md`. Ejecuta `database/07_optimization/02_aplicar_indices_r4.sql` para crear los índices candidatos documentados; el script verifica los nombres antes de crearlos y no modifica datos. Guarda el listado que devuelve. La primera medición mostró que el índice filtrado de pagos no reduce lecturas; ejecuta `database/07_optimization/05_retirar_indice_pago_r4.sql` para retirarlo antes de la captura final. Luego confirma que quedan cuatro índices.

Repite exactamente las mismas consultas, negocio, fechas y estados con `database/07_optimization/03_capturar_planes_despues.sql` después de aplicar los índices y retirar el índice de pagos. Guarda la captura final como `docs/optimizacion/despues/04_planes_despues_final.sqlplan` y sus mensajes en `docs/optimizacion/despues/04_estadisticas_despues_final.txt`. Conserva también los archivos de la primera medición con cinco índices para documentar por qué se retiró el de pagos. La comparación medida está documentada en `docs/optimizacion/resultado.md`. Los costos estimados no representan milisegundos; los tiempos transcurridos deben compararse solo con estado de caché equivalente.

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

La selección es una hipótesis de trabajo por su función y filtros. El script de preparación crea un volumen sintético y aislado; el diagnóstico documentará que la comparación corresponde a ese escenario de prueba.

Después de terminar y revisar las capturas, limpia únicamente los datos temporales ejecutando database/05_tests/12_limpiar_escenario_rendimiento.sql. No ejecutes la limpieza antes de guardar los planes y estadísticas.








