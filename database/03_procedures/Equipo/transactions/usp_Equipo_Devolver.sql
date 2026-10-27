USE RentaTicaDB;
GO

/* Nombre: usp_Equipo_Devolver
   Descripcion: Registra la devolucion de un detalle, actualiza el equipo,
                cierra la reserva al devolver todos sus equipos y liquida la
                garantia en la ultima devolucion cuando existe.
   Parametros: detalle_id, negocio_id, estado de devolucion, montos del deposito,
               usuario_id opcional.
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Equipo_Devolver
    @detalle_id INT,@negocio_id INT,@estado_devolucion VARCHAR(20),
    @monto_devuelto DECIMAL(10,2)=NULL,@monto_retencion DECIMAL(10,2)=NULL,@usuario_id INT=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        IF @estado_devolucion IS NULL OR @estado_devolucion NOT IN ('Bueno','Averiado','Perdido')
            THROW 50003,'Estado de devolucion invalido.',1;
        BEGIN TRANSACTION;
        DECLARE @reserva_id INT,@equipo_id INT,@devuelta DATETIME;
        SELECT @reserva_id=d.reserva_id,@equipo_id=d.equipo_id,@devuelta=d.fecha_hora_devolucion
        FROM renta.DetalleReserva d WITH(UPDLOCK,HOLDLOCK)
        JOIN renta.Reserva r ON r.reserva_id=d.reserva_id
        WHERE d.detalle_id=@detalle_id AND r.negocio_id=@negocio_id;
        IF @reserva_id IS NULL THROW 50001,'El detalle no existe en el negocio.',1;
        IF @devuelta IS NOT NULL THROW 50004,'El equipo ya fue devuelto.',1;
        UPDATE renta.DetalleReserva SET fecha_hora_devolucion=GETDATE(),estado_equipo_devolucion=@estado_devolucion
        WHERE detalle_id=@detalle_id;
        EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=@usuario_id;
        UPDATE renta.Equipo SET estado=CASE @estado_devolucion WHEN 'Bueno' THEN 'Disponible'
                       WHEN 'Averiado' THEN 'Averiado' ELSE 'Fuera de servicio' END
        WHERE equipo_id=@equipo_id;
        IF NOT EXISTS(SELECT 1 FROM renta.DetalleReserva WHERE reserva_id=@reserva_id AND fecha_hora_devolucion IS NULL)
        BEGIN
            UPDATE renta.Reserva SET estado='Completada' WHERE reserva_id=@reserva_id;
            IF EXISTS(SELECT 1 FROM renta.Deposito WHERE reserva_id=@reserva_id AND fecha_devolucion IS NULL)
            BEGIN
                IF @monto_devuelto IS NULL OR @monto_retencion IS NULL OR @monto_devuelto<0 OR @monto_retencion<0
                    THROW 50003,'Indique montos validos para liquidar el deposito.',1;
                IF NOT EXISTS(SELECT 1 FROM renta.Deposito WHERE reserva_id=@reserva_id
                              AND monto_cobrado=@monto_devuelto+@monto_retencion AND fecha_devolucion IS NULL)
                    THROW 50003,'La devolucion y retencion deben sumar el deposito cobrado.',1;
                UPDATE renta.Deposito SET monto_devuelto=@monto_devuelto,monto_retencion=@monto_retencion,
                       fecha_devolucion=GETDATE() WHERE reserva_id=@reserva_id AND fecha_devolucion IS NULL;
            END
        END
        ELSE IF @monto_devuelto IS NOT NULL OR @monto_retencion IS NOT NULL
            THROW 50004,'La garantia se liquida con la ultima devolucion.',1;
        EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=NULL;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=NULL;
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
