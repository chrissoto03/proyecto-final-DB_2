USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_MetodoPago_Listar
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_MetodoPago_Listar
   Descripcion: Lista los metodos de pago ordenados por nombre.
   Retorna:     metodo_pago_id, nombre
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT metodo_pago_id, nombre FROM renta.MetodoPago ORDER BY nombre;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
