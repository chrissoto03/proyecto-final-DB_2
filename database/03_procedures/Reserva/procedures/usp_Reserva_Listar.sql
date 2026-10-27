USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Reserva_Listar
    @negocio_id INT,
    @estado     VARCHAR(20) = NULL,
    @cliente_id INT = NULL,
    @desde      DATETIME = NULL,
    @hasta      DATETIME = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Reserva_Listar
   Descripcion: Lista las reservas del negocio con filtros opcionales por
                estado, cliente y rango de fecha de inicio [desde, hasta).
   Parametros:  @negocio_id, @estado, @cliente_id, @desde, @hasta
   Errores:     50003 estado o rango invalido
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @estado IS NOT NULL AND @estado NOT IN ('Pendiente','Confirmada','En curso','Completada','Cancelada')
            THROW 50003, 'Estado de reserva invalido.', 1;
        IF @desde IS NOT NULL AND @hasta IS NOT NULL AND @hasta <= @desde
            THROW 50003, 'El rango de fechas es invalido.', 1;

        SELECT r.reserva_id, r.tipo_reserva, r.estado, r.fecha_reserva, r.fecha_inicio, r.fecha_fin,
               r.monto_final, r.cliente_id, uc.nombre_completo AS cliente,
               r.operador_id, uo.nombre_completo AS operador,
               (SELECT COUNT(*) FROM renta.DetalleReserva d WHERE d.reserva_id = r.reserva_id) AS total_equipos
        FROM renta.Reserva r
        INNER JOIN renta.Usuario uc ON uc.usuario_id = r.cliente_id
        LEFT JOIN renta.Usuario uo ON uo.usuario_id = r.operador_id
        WHERE r.negocio_id = @negocio_id
          AND (@estado     IS NULL OR r.estado     = @estado)
          AND (@cliente_id IS NULL OR r.cliente_id = @cliente_id)
          AND (@desde      IS NULL OR r.fecha_inicio >= @desde)
          AND (@hasta      IS NULL OR r.fecha_inicio <  @hasta)
        ORDER BY r.fecha_inicio DESC, r.reserva_id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
