/* R4 - Retira el índice de pagos que no mostró beneficio en el escenario medido.
   No elimina ni modifica filas. Conserva los otros cuatro índices candidatos. */
USE RentaTicaDB;
GO
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'renta.Pago') AND name=N'IX_Pago_Fecha_Completado')
    DROP INDEX IX_Pago_Fecha_Completado ON renta.Pago;
SELECT name AS indice_restante FROM sys.indexes
WHERE name IN (N'IX_CategoriaEquipo_Negocio',N'IX_Equipo_Categoria_Estado_Codigo',
               N'IX_Reserva_Negocio_FechaInicio',N'IX_DetalleReserva_Reserva')
ORDER BY name;
GO
