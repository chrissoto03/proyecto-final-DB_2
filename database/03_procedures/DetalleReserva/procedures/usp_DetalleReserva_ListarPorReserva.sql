USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_DetalleReserva_ListarPorReserva
    @reserva_id INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_DetalleReserva_ListarPorReserva
   Descripcion: Lista los equipos de una reserva.
   Parametros:  @reserva_id, @negocio_id
   Errores:     50001 la reserva no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Reserva WHERE reserva_id = @reserva_id AND negocio_id = @negocio_id)
            THROW 50001, 'La reserva no existe en este negocio.', 1;

        SELECT d.detalle_id, d.equipo_id, e.codigo_interno, c.nombre AS categoria,
               d.tarifa_aplicada, d.fecha_hora_entrega, d.fecha_hora_devolucion,
               d.estado_equipo_devolucion
        FROM renta.DetalleReserva d
        INNER JOIN renta.Equipo e ON e.equipo_id = d.equipo_id
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE d.reserva_id = @reserva_id
        ORDER BY d.detalle_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
