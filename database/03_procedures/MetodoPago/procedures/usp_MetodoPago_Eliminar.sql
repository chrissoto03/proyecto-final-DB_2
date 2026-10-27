USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_MetodoPago_Eliminar
    @metodo_pago_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_MetodoPago_Eliminar
   Descripcion: Elimina un metodo de pago que no tenga pagos registrados.
   Parametros:  @metodo_pago_id (entrada)
   Errores:     50001 no existe; 50002 tiene pagos asociados
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.MetodoPago WHERE metodo_pago_id = @metodo_pago_id)
            THROW 50001, 'El metodo de pago no existe.', 1;

        IF EXISTS (SELECT 1 FROM renta.Pago WHERE metodo_pago_id = @metodo_pago_id)
            THROW 50002, 'No se puede eliminar: hay pagos registrados con este metodo.', 1;

        DELETE FROM renta.MetodoPago WHERE metodo_pago_id = @metodo_pago_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
