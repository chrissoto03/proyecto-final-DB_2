USE RentaTicaDB;
GO

/* ############################################################################
   DEPOSITO
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Deposito_ObtenerPorReserva
    @reserva_id INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Deposito_ObtenerPorReserva
   Descripcion: Devuelve el deposito de garantia de una reserva (relacion 1:1).
   Parametros:  @reserva_id, @negocio_id
   Errores:     50001 la reserva no existe en el negocio o no tiene deposito
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Deposito d
                       INNER JOIN renta.Reserva r ON r.reserva_id = d.reserva_id
                       WHERE d.reserva_id = @reserva_id AND r.negocio_id = @negocio_id)
            THROW 50001, 'La reserva no existe en este negocio o no tiene deposito.', 1;

        SELECT d.deposito_id, d.reserva_id, d.monto_cobrado, d.monto_devuelto,
               d.monto_retencion, d.fecha_devolucion,
               CASE WHEN d.fecha_devolucion IS NULL THEN 'Pendiente de liquidar' ELSE 'Liquidado' END AS situacion
        FROM renta.Deposito d
        WHERE d.reserva_id = @reserva_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
