USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_MetodoPago_ObtenerPorId
    @metodo_pago_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_MetodoPago_ObtenerPorId
   Descripcion: Devuelve un metodo de pago por su id.
   Parametros:  @metodo_pago_id (entrada)
   Retorna:     metodo_pago_id, nombre
   Errores:     50001 no existe
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.MetodoPago WHERE metodo_pago_id = @metodo_pago_id)
            THROW 50001, 'El metodo de pago no existe.', 1;

        SELECT metodo_pago_id, nombre
        FROM renta.MetodoPago
        WHERE metodo_pago_id = @metodo_pago_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
