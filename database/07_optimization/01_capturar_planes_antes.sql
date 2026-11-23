/*
R4 - Captura de línea base ANTES de crear índices.
Solo consulta datos; no modifica tablas ni objetos.
En SSMS: activar Include Actual Execution Plan (Ctrl+M), ejecutar el archivo completo,
guardar los planes con sufijos 01_inventario_antes, 02_reservas_proximas_antes
y 03_ingresos_antes, y conservar el texto de Messages (STATISTICS IO/TIME).
*/
USE RentaTicaDB;
GO
SET NOCOUNT ON;

DECLARE @negocio_id INT;
DECLARE @desde DATE = DATEADD(DAY, -90, CONVERT(DATE, GETDATE()));
DECLARE @hasta DATE = CONVERT(DATE, GETDATE());

/* Escoge el negocio con mayor volumen combinado de equipos y reservas. */
SELECT TOP (1) @negocio_id = n.negocio_id
FROM renta.Negocio AS n
ORDER BY
    (SELECT COUNT_BIG(*)
     FROM renta.CategoriaEquipo AS c
     INNER JOIN renta.Equipo AS e ON e.categoria_id = c.categoria_id
     WHERE c.negocio_id = n.negocio_id)
    +
    (SELECT COUNT_BIG(*)
     FROM renta.Reserva AS r
     WHERE r.negocio_id = n.negocio_id) DESC,
    n.negocio_id;

IF @negocio_id IS NULL
    THROW 51000, 'No hay negocios para capturar planes R4.', 1;

PRINT 'R4 - LINEA BASE ANTES DE OPTIMIZAR';
PRINT 'negocio_id seleccionado:';
PRINT @negocio_id;
PRINT 'Fechas del reporte de ingresos: ultimos 90 dias hasta hoy.';

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

/* 1. Consulta frecuente: inventario por negocio y estado. */
PRINT 'PLAN 01 - usp_Equipo_ListarPorEstado';
EXEC renta.usp_Equipo_ListarPorEstado
    @negocio_id = @negocio_id,
    @estado = 'Disponible';

/* 2. Consulta frecuente: reservas próximas y conteo de equipos por reserva. */
PRINT 'PLAN 02 - usp_Reserva_Proximas';
EXEC renta.usp_Reserva_Proximas
    @negocio_id = @negocio_id,
    @dias = 30;

/* 3. Consulta de reporte: ingresos completados agrupados por día. */
PRINT 'PLAN 03 - usp_Reporte_IngresosPorDia';
EXEC renta.usp_Reporte_IngresosPorDia
    @negocio_id = @negocio_id,
    @desde = @desde,
    @hasta = @hasta;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO


