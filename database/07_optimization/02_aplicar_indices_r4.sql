/* R4 - Índices candidatos derivados de los planes base guardados en docs/optimizacion/antes.
   Ejecutar solo después de conservar la línea base. Todos son índices no únicos y no cambian datos.
   Si ya existen con estos nombres, se dejan intactos. */
USE RentaTicaDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
BEGIN TRY
    BEGIN TRANSACTION;

    /* Equipo_ListarPorEstado: resolver categorías del tenant y cubrir nombre/categoría. */
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.CategoriaEquipo') AND name=N'IX_CategoriaEquipo_Negocio')
        CREATE NONCLUSTERED INDEX IX_CategoriaEquipo_Negocio
            ON renta.CategoriaEquipo(negocio_id)
            INCLUDE(nombre);

    /* Equipo_ListarPorEstado: filtrar por categoría y estado, devolver código y descripción ordenados. */
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.Equipo') AND name=N'IX_Equipo_Categoria_Estado_Codigo')
        CREATE NONCLUSTERED INDEX IX_Equipo_Categoria_Estado_Codigo
            ON renta.Equipo(categoria_id, estado, codigo_interno)
            INCLUDE(descripcion);

    /* Reserva_Proximas: buscar por tenant y rango, cubriendo sus columnas de salida/filtro. */
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.Reserva') AND name=N'IX_Reserva_Negocio_FechaInicio')
        CREATE NONCLUSTERED INDEX IX_Reserva_Negocio_FechaInicio
            ON renta.Reserva(negocio_id, fecha_inicio)
            INCLUDE(estado, tipo_reserva, fecha_fin, cliente_id);

    /* Reserva_Proximas: la subconsulta correlacionada cuenta detalles por reserva. */
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.DetalleReserva') AND name=N'IX_DetalleReserva_Reserva')
        CREATE NONCLUSTERED INDEX IX_DetalleReserva_Reserva
            ON renta.DetalleReserva(reserva_id);

    /* Reporte_IngresosPorDia: filtrar pagos completados por fecha y cubrir join/agregación. */
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.Pago') AND name=N'IX_Pago_Fecha_Completado')
        CREATE NONCLUSTERED INDEX IX_Pago_Fecha_Completado
            ON renta.Pago(fecha_pago, reserva_id)
            INCLUDE(monto)
            WHERE estado='Completado';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT OBJECT_SCHEMA_NAME(i.object_id) AS esquema, OBJECT_NAME(i.object_id) AS tabla, i.name AS indice
FROM sys.indexes AS i
WHERE i.name IN (N'IX_CategoriaEquipo_Negocio',N'IX_Equipo_Categoria_Estado_Codigo',
                 N'IX_Reserva_Negocio_FechaInicio',N'IX_DetalleReserva_Reserva',N'IX_Pago_Fecha_Completado')
ORDER BY tabla, indice;
GO

