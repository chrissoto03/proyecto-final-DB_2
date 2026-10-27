USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Rol_ObtenerPorId
    @rol_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Rol_ObtenerPorId
   Descripcion: Devuelve un rol por su id.
   Parametros:  @rol_id (entrada)
   Retorna:     rol_id, nombre
   Errores:     50001 no existe
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Rol WHERE rol_id = @rol_id)
            THROW 50001, 'El rol no existe.', 1;

        SELECT rol_id, nombre FROM renta.Rol WHERE rol_id = @rol_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
