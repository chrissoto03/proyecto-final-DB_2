USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Reserva_Eliminar
    @reserva_id INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Reserva_Eliminar
   Descripcion: TRANSACCION. Elimina una reserva CANCELADA que nunca tuvo pagos
                ni deposito, junto con su detalle. Toca dos tablas, por eso
                es atomica: o se borran ambas o ninguna.
   Parametros:  @reserva_id, @negocio_id
   Errores:     50001 no existe en el negocio; 50004 no esta cancelada;
                50002 tiene pagos o deposito
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @estado VARCHAR(20) =
            (SELECT estado FROM renta.Reserva WHERE reserva_id = @reserva_id AND negocio_id = @negocio_id);

        IF @estado IS NULL
            THROW 50001, 'La reserva no existe en este negocio.', 1;
        IF @estado <> 'Cancelada'
            THROW 50004, 'Solo se pueden eliminar reservas canceladas.', 1;
        IF EXISTS (SELECT 1 FROM renta.Pago     WHERE reserva_id = @reserva_id)
           OR EXISTS (SELECT 1 FROM renta.Deposito WHERE reserva_id = @reserva_id)
            THROW 50002, 'La reserva tiene pagos o deposito registrados y debe conservarse.', 1;

        BEGIN TRANSACTION;

        DELETE FROM renta.DetalleReserva WHERE reserva_id = @reserva_id;
        DELETE FROM renta.Reserva        WHERE reserva_id = @reserva_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
