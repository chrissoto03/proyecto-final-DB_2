USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Reserva_ListarPorCliente
    @cliente_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Reserva_ListarPorCliente
   Descripcion: Historial de reservas de un cliente en TODOS los negocios de la
                plataforma (el cliente es compartido entre negocios).
   Parametros:  @cliente_id
   Errores:     50001 el cliente no existe
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Usuario WHERE usuario_id = @cliente_id)
            THROW 50001, 'El cliente no existe.', 1;

        SELECT r.reserva_id, r.negocio_id, n.nombre AS negocio, r.tipo_reserva, r.estado,
               r.fecha_inicio, r.fecha_fin, r.monto_final,
               (SELECT COUNT(*) FROM renta.DetalleReserva d WHERE d.reserva_id = r.reserva_id) AS total_equipos
        FROM renta.Reserva r
        INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
        WHERE r.cliente_id = @cliente_id
        ORDER BY r.fecha_inicio DESC, r.reserva_id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
