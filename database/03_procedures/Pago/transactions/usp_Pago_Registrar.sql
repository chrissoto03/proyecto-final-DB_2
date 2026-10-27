USE RentaTicaDB;
GO

/* Nombre: usp_Pago_Registrar
   Descripcion: Registra un abono y confirma la reserva cuando queda pagada.
   Parametros: reserva_id, negocio_id, metodo_pago_id, monto, pago_id OUTPUT.
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Pago_Registrar
    @reserva_id INT,@negocio_id INT,@metodo_pago_id INT,@monto DECIMAL(10,2),@pago_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        IF @monto IS NULL OR @monto<=0 THROW 50003,'El monto debe ser mayor que cero.',1;
        BEGIN TRANSACTION;
        DECLARE @total DECIMAL(10,2),@pagado DECIMAL(10,2),@estado VARCHAR(20);
        SELECT @total=monto_final,@estado=estado FROM renta.Reserva WITH(UPDLOCK,HOLDLOCK)
        WHERE reserva_id=@reserva_id AND negocio_id=@negocio_id;
        IF @total IS NULL THROW 50001,'La reserva no existe en el negocio.',1;
        IF @estado='Cancelada' THROW 50004,'No se puede cobrar una reserva cancelada.',1;
        IF NOT EXISTS(SELECT 1 FROM renta.MetodoPago WHERE metodo_pago_id=@metodo_pago_id)
            THROW 50003,'El metodo de pago no existe.',1;
        SELECT @pagado=ISNULL(SUM(monto),0) FROM renta.Pago WHERE reserva_id=@reserva_id AND estado='Completado';
        IF @pagado+@monto>@total THROW 50004,'El pago supera el saldo pendiente.',1;
        INSERT INTO renta.Pago(reserva_id,metodo_pago_id,monto) VALUES(@reserva_id,@metodo_pago_id,@monto);
        SET @pago_id=CONVERT(INT,SCOPE_IDENTITY());
        IF @pagado+@monto=@total AND @estado='Pendiente'
            UPDATE renta.Reserva SET estado='Confirmada' WHERE reserva_id=@reserva_id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH
END
GO
