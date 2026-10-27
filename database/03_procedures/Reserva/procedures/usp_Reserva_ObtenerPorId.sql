USE RentaTicaDB;
GO

/* ############################################################################
   RESERVA
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Reserva_ObtenerPorId
    @reserva_id INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Reserva_ObtenerPorId
   Descripcion: Devuelve la reserva completa en 4 result sets:
                1) encabezado (con total pagado y saldo)  2) equipos
                3) pagos  4) deposito
   Parametros:  @reserva_id, @negocio_id
   Errores:     50001 no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Reserva WHERE reserva_id = @reserva_id AND negocio_id = @negocio_id)
            THROW 50001, 'La reserva no existe en este negocio.', 1;

        SELECT r.reserva_id, r.negocio_id, r.tipo_reserva, r.estado, r.fecha_reserva,
               r.fecha_inicio, r.fecha_fin, r.monto_final,
               ISNULL((SELECT SUM(p.monto) FROM renta.Pago p
                       WHERE p.reserva_id = r.reserva_id AND p.estado = 'Completado'), 0) AS total_pagado,
               r.monto_final - ISNULL((SELECT SUM(p.monto) FROM renta.Pago p
                       WHERE p.reserva_id = r.reserva_id AND p.estado = 'Completado'), 0) AS saldo,
               r.cliente_id, uc.nombre_completo AS cliente,
               r.operador_id, uo.nombre_completo AS operador
        FROM renta.Reserva r
        INNER JOIN renta.Usuario uc ON uc.usuario_id = r.cliente_id
        LEFT JOIN renta.Usuario uo ON uo.usuario_id = r.operador_id
        WHERE r.reserva_id = @reserva_id;

        SELECT d.detalle_id, d.equipo_id, e.codigo_interno, c.nombre AS categoria,
               d.tarifa_aplicada, d.fecha_hora_entrega, d.fecha_hora_devolucion,
               d.estado_equipo_devolucion
        FROM renta.DetalleReserva d
        INNER JOIN renta.Equipo e ON e.equipo_id = d.equipo_id
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE d.reserva_id = @reserva_id;

        SELECT p.pago_id, p.monto, m.nombre AS metodo_pago, p.fecha_pago, p.estado
        FROM renta.Pago p
        INNER JOIN renta.MetodoPago m ON m.metodo_pago_id = p.metodo_pago_id
        WHERE p.reserva_id = @reserva_id
        ORDER BY p.fecha_pago;

        SELECT deposito_id, monto_cobrado, monto_devuelto, monto_retencion, fecha_devolucion
        FROM renta.Deposito
        WHERE reserva_id = @reserva_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
