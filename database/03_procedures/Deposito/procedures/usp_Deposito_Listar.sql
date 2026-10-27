USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Deposito_Listar
    @negocio_id      INT,
    @solo_pendientes BIT = 0
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Deposito_Listar
   Descripcion: Lista los depositos del negocio. Con @solo_pendientes = 1
                muestra solo los que aun no se liquidan, es decir, el dinero
                de clientes que el negocio mantiene en custodia.
   Parametros:  @negocio_id, @solo_pendientes
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT d.deposito_id, d.reserva_id, uc.nombre_completo AS cliente, r.estado AS estado_reserva,
               d.monto_cobrado, d.monto_devuelto, d.monto_retencion, d.fecha_devolucion,
               CASE WHEN d.fecha_devolucion IS NULL THEN 'Pendiente de liquidar' ELSE 'Liquidado' END AS situacion
        FROM renta.Deposito d
        INNER JOIN renta.Reserva r ON r.reserva_id = d.reserva_id
        INNER JOIN renta.Usuario uc ON uc.usuario_id = r.cliente_id
        WHERE r.negocio_id = @negocio_id
          AND (@solo_pendientes = 0 OR d.fecha_devolucion IS NULL)
        ORDER BY d.deposito_id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
