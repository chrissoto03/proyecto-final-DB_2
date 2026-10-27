USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Pago_ListarPorReserva
    @reserva_id INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Pago_ListarPorReserva
   Descripcion: Lista los pagos de una reserva.
   Parametros:  @reserva_id, @negocio_id
   Errores:     50001 la reserva no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Reserva WHERE reserva_id = @reserva_id AND negocio_id = @negocio_id)
            THROW 50001, 'La reserva no existe en este negocio.', 1;

        SELECT p.pago_id, p.monto, p.metodo_pago_id, m.nombre AS metodo_pago, p.fecha_pago, p.estado
        FROM renta.Pago p
        INNER JOIN renta.MetodoPago m ON m.metodo_pago_id = p.metodo_pago_id
        WHERE p.reserva_id = @reserva_id
        ORDER BY p.fecha_pago, p.pago_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
