USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Pago_Listar
    @negocio_id     INT,
    @desde          DATETIME = NULL,
    @hasta          DATETIME = NULL,
    @metodo_pago_id INT = NULL,
    @estado         VARCHAR(20) = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Pago_Listar
   Descripcion: Lista los pagos del negocio con filtros opcionales por rango de
                fechas [desde, hasta), metodo de pago y estado.
   Parametros:  @negocio_id, @desde, @hasta, @metodo_pago_id, @estado
   Errores:     50003 estado o rango invalido
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @estado IS NOT NULL AND @estado NOT IN ('Completado', 'Reembolsado')
            THROW 50003, 'Estado de pago invalido.', 1;
        IF @desde IS NOT NULL AND @hasta IS NOT NULL AND @hasta <= @desde
            THROW 50003, 'El rango de fechas es invalido.', 1;

        SELECT p.pago_id, p.reserva_id, p.monto, m.nombre AS metodo_pago, p.fecha_pago, p.estado,
               uc.nombre_completo AS cliente
        FROM renta.Pago p
        INNER JOIN renta.Reserva r ON r.reserva_id = p.reserva_id
        INNER JOIN renta.MetodoPago m ON m.metodo_pago_id = p.metodo_pago_id
        INNER JOIN renta.Usuario uc ON uc.usuario_id = r.cliente_id
        WHERE r.negocio_id = @negocio_id
          AND (@desde          IS NULL OR p.fecha_pago >= @desde)
          AND (@hasta          IS NULL OR p.fecha_pago <  @hasta)
          AND (@metodo_pago_id IS NULL OR p.metodo_pago_id = @metodo_pago_id)
          AND (@estado         IS NULL OR p.estado = @estado)
        ORDER BY p.fecha_pago DESC, p.pago_id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
