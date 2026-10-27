USE RentaTicaDB;
GO

/* ############################################################################
   PAGO
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Pago_ObtenerPorId
    @pago_id    INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Pago_ObtenerPorId
   Descripcion: Devuelve un pago.
   Parametros:  @pago_id, @negocio_id
   Errores:     50001 no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Pago p
                       INNER JOIN renta.Reserva r ON r.reserva_id = p.reserva_id
                       WHERE p.pago_id = @pago_id AND r.negocio_id = @negocio_id)
            THROW 50001, 'El pago no existe en este negocio.', 1;

        SELECT p.pago_id, p.reserva_id, p.monto, p.metodo_pago_id, m.nombre AS metodo_pago,
               p.fecha_pago, p.estado
        FROM renta.Pago p
        INNER JOIN renta.MetodoPago m ON m.metodo_pago_id = p.metodo_pago_id
        WHERE p.pago_id = @pago_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
