# R4 - Resultado de análisis de rendimiento

## Entorno y método

- SQL Server: 17.0 RTM (17.0.1000.7 en el plan), base `RentaTicaDB`.
- Fecha: 2026-11-23.
- Escenario aislado: `r4-benchmark@prueba.test`, `negocio_id=16`, 250 equipos, 40 reservas y 40 pagos.
- Consultas: inventario Disponible, reservas próximas en 30 días, ingresos del 2026-08-25 al 2026-11-23 inclusive.
- Línea base: `antes/00_linea_base_completa.sqlplan` y `antes/estadisticas.txt`.
- Primera prueba con cinco índices: `despues/02_planes_despues.sqlplan`, `despues/03_planes_despues.sqlplan`, `despues/estadisticas.txt`.
- Estado final con cuatro índices: `despues/04_planes_despues_final.sqlplan` y `despues/04_estadisticas_despues_final.txt`.

## Comparación final

| Consulta | Plan antes | Plan final | Costo estimado antes → final | Lecturas lógicas antes → final | Filas estimadas/real antes → final |
|---|---|---|---:|---:|---:|
| `usp_Equipo_ListarPorEstado` | Escaneo de categoría, índice único de equipo más búsquedas PK y ordenamiento. | Seek en `IX_CategoriaEquipo_Negocio` y `IX_Equipo_Categoria_Estado_Codigo`; se conserva ordenamiento. | 0.0212201 → 0.0179318 (-15.5%) | 425 → 5 (-98.8%) | 1/210 → 1/210 |
| `usp_Reserva_Proximas` | Escaneo de reserva y escaneo correlacionado de detalle, 40 ejecuciones. | Seek en `IX_Reserva_Negocio_FechaInicio` y `IX_DetalleReserva_Reserva`; seek de usuario. | 0.0215664 → 0.0102199 (-52.6%) | 162 → 162 | 6.32456/40 → 1.06156/40 |
| `usp_Reporte_IngresosPorDia` | Escaneo de Pago y seek de Reserva. | Escaneo de Pago y seek de Reserva; sin índice filtrado de pago. | 0.0185195 → 0.0185204 (+0.005%) | 82 → 82 | 1/1 → 1/1 |

La estimación de filas para inventario siguió en 1 frente a 210 reales; la búsqueda mejoró lecturas, pero no resolvió la subestimación. En reservas la estimación bajó de 6.32456 a 1.06156 frente a 40 reales, así que el error de cardinalidad persiste y debe quedar documentado. El inventario mostró una mejora clara en accesos y lecturas lógicas. En reservas el plan cambia a búsquedas y baja el costo estimado, aunque las lecturas lógicas totales no cambiaron en este conjunto pequeño. El reporte no mostró beneficio medible; el índice filtrado de Pago fue retirado mediante `05_retirar_indice_pago_r4.sql` y no forma parte del estado final.

Los costos estimados son unidades internas de SQL Server, no milisegundos. Los tiempos transcurridos no se comparan porque la línea base tuvo cero lecturas físicas y las capturas posteriores tuvieron lecturas físicas; las condiciones de caché fueron distintas.

## Índices que quedan instalados

- `IX_CategoriaEquipo_Negocio` (`CategoriaEquipo(negocio_id) INCLUDE (nombre)`).
- `IX_Equipo_Categoria_Estado_Codigo` (`Equipo(categoria_id, estado, codigo_interno) INCLUDE (descripcion)`).
- `IX_Reserva_Negocio_FechaInicio` (`Reserva(negocio_id, fecha_inicio) INCLUDE (estado, tipo_reserva, fecha_fin, cliente_id)`).
- `IX_DetalleReserva_Reserva` (`DetalleReserva(reserva_id)`).

El script `04_revertir_indices_r4.sql` elimina únicamente esos índices candidatos si se decide revertirlos. No se deben ejecutar scripts de esquema sobre tablas ya instaladas.

## Limpieza del escenario temporal

Después de conservar los archivos de planes y estadísticas, ejecutar `database/05_tests/12_limpiar_escenario_rendimiento.sql`. Ese script elimina solo el negocio de prueba `r4-benchmark@prueba.test` y sus datos asociados.

