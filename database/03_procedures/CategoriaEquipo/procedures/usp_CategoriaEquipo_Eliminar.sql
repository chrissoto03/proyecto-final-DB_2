USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_CategoriaEquipo_Eliminar
    @categoria_id INT,
    @negocio_id   INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_CategoriaEquipo_Eliminar
   Descripcion: Elimina una categoria que no tenga equipos.
   Parametros:  @categoria_id, @negocio_id
   Errores:     50001 no existe en el negocio; 50002 tiene equipos
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.CategoriaEquipo
                       WHERE categoria_id = @categoria_id AND negocio_id = @negocio_id)
            THROW 50001, 'La categoria no existe en este negocio.', 1;
        IF EXISTS (SELECT 1 FROM renta.Equipo WHERE categoria_id = @categoria_id)
            THROW 50002, 'La categoria tiene equipos asociados.', 1;

        DELETE FROM renta.CategoriaEquipo WHERE categoria_id = @categoria_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
