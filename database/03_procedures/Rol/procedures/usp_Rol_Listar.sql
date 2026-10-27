USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Rol_Listar
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Rol_Listar
   Descripcion: Lista todos los roles ordenados por nombre.
   Retorna:     rol_id, nombre
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT rol_id, nombre FROM renta.Rol ORDER BY nombre;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
