USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Negocio_CambiarEstado
    @negocio_id INT,
    @estado     VARCHAR(20)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Negocio_CambiarEstado
   Descripcion: Activa o suspende un negocio (baja logica).
   Parametros:  @negocio_id, @estado ('Activo' o 'Suspendido')
   Errores:     50003 estado invalido; 50001 no existe
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @estado IS NULL OR @estado NOT IN ('Activo', 'Suspendido')
            THROW 50003, 'El estado debe ser Activo o Suspendido.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id)
            THROW 50001, 'El negocio no existe.', 1;

        UPDATE renta.Negocio SET estado = @estado WHERE negocio_id = @negocio_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
