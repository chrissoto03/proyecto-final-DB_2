USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_MetodoPago_Modificar
    @metodo_pago_id INT,
    @nombre         VARCHAR(30)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_MetodoPago_Modificar
   Descripcion: Cambia el nombre de un metodo de pago.
   Parametros:  @metodo_pago_id, @nombre (entrada)
   Errores:     50001 no existe; 50003 nombre vacio; 50002 nombre duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50003, 'El nombre del metodo de pago es obligatorio.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.MetodoPago WHERE metodo_pago_id = @metodo_pago_id)
            THROW 50001, 'El metodo de pago no existe.', 1;

        UPDATE renta.MetodoPago
        SET nombre = LTRIM(RTRIM(@nombre))
        WHERE metodo_pago_id = @metodo_pago_id;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un metodo de pago con ese nombre.', 1;
        THROW;
    END CATCH
END
GO
