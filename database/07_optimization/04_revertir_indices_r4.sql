/* R4 - Revertir solo los índices candidatos de este avance.
   Usar únicamente si la comparación posterior no muestra beneficio o si el equipo decide retirarlos. */
USE RentaTicaDB;
GO
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.CategoriaEquipo') AND name=N'IX_CategoriaEquipo_Negocio')
        DROP INDEX IX_CategoriaEquipo_Negocio ON renta.CategoriaEquipo;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.Equipo') AND name=N'IX_Equipo_Categoria_Estado_Codigo')
        DROP INDEX IX_Equipo_Categoria_Estado_Codigo ON renta.Equipo;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.Reserva') AND name=N'IX_Reserva_Negocio_FechaInicio')
        DROP INDEX IX_Reserva_Negocio_FechaInicio ON renta.Reserva;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.DetalleReserva') AND name=N'IX_DetalleReserva_Reserva')
        DROP INDEX IX_DetalleReserva_Reserva ON renta.DetalleReserva;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.Pago') AND name=N'IX_Pago_Fecha_Completado')
        DROP INDEX IX_Pago_Fecha_Completado ON renta.Pago;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
