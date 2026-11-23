/* R4 - Captura DESPUÉS de instalar los índices candidatos.
   Requiere conservar el escenario r4-benchmark creado el 2026-11-23.
   Usa el mismo negocio, estado, horizonte y fechas del script base de esa ejecución. */
USE RentaTicaDB;
GO
SET NOCOUNT ON;
DECLARE @negocio_id INT=(SELECT negocio_id FROM renta.Negocio WHERE email_contacto='r4-benchmark@prueba.test');
DECLARE @desde DATE='20260825', @hasta DATE='20261123';
IF @negocio_id IS NULL
    THROW 51010, 'No existe el negocio temporal R4. Ejecute primero 11_preparar_escenario_rendimiento.sql.', 1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE name IN (N'IX_CategoriaEquipo_Negocio',N'IX_Equipo_Categoria_Estado_Codigo',N'IX_Reserva_Negocio_FechaInicio',N'IX_DetalleReserva_Reserva')) <> 4
    THROW 51011, 'Falta instalar uno o mas de los cuatro indices R4 vigentes. Revise el listado antes de capturar.', 1;
SELECT @negocio_id AS negocio_id, @desde AS fecha_desde, @hasta AS fecha_hasta;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

PRINT 'PLAN 01 - DESPUES - usp_Equipo_ListarPorEstado';
EXEC renta.usp_Equipo_ListarPorEstado @negocio_id=@negocio_id, @estado='Disponible';

PRINT 'PLAN 02 - DESPUES - usp_Reserva_Proximas';
EXEC renta.usp_Reserva_Proximas @negocio_id=@negocio_id, @dias=30;

PRINT 'PLAN 03 - DESPUES - usp_Reporte_IngresosPorDia';
EXEC renta.usp_Reporte_IngresosPorDia @negocio_id=@negocio_id, @desde=@desde, @hasta=@hasta;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO



