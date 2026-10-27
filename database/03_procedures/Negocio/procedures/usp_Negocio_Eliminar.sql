USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Negocio_Eliminar
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Negocio_Eliminar
   Descripcion: Elimina un negocio que no tenga usuarios, categorias ni
                reservas. Si ya tiene historial se debe suspender.
   Parametros:  @negocio_id (entrada)
   Errores:     50001 no existe; 50002 tiene datos asociados
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id)
            THROW 50001, 'El negocio no existe.', 1;

        IF EXISTS (SELECT 1 FROM renta.Usuario         WHERE negocio_id = @negocio_id)
           OR EXISTS (SELECT 1 FROM renta.CategoriaEquipo WHERE negocio_id = @negocio_id)
           OR EXISTS (SELECT 1 FROM renta.Reserva         WHERE negocio_id = @negocio_id)
            THROW 50002, 'El negocio tiene datos asociados. Suspendalo en lugar de eliminarlo.', 1;

        DELETE FROM renta.Negocio WHERE negocio_id = @negocio_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
