USE RentaTicaDB;
GO

/* ############################################################################
   DETALLE RESERVA
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_DetalleReserva_ObtenerPorId
    @detalle_id INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_DetalleReserva_ObtenerPorId
   Descripcion: Devuelve una linea de reserva (un equipo dentro de una reserva).
   Parametros:  @detalle_id, @negocio_id
   Errores:     50001 no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.DetalleReserva d
                       INNER JOIN renta.Reserva r ON r.reserva_id = d.reserva_id
                       WHERE d.detalle_id = @detalle_id AND r.negocio_id = @negocio_id)
            THROW 50001, 'El detalle de reserva no existe en este negocio.', 1;

        SELECT d.detalle_id, d.reserva_id, d.equipo_id, e.codigo_interno, c.nombre AS categoria,
               d.tarifa_aplicada, d.fecha_hora_entrega, d.fecha_hora_devolucion,
               d.estado_equipo_devolucion
        FROM renta.DetalleReserva d
        INNER JOIN renta.Equipo e ON e.equipo_id = d.equipo_id
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE d.detalle_id = @detalle_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
