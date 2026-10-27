USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Negocio_ObtenerPorId
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Negocio_ObtenerPorId
   Descripcion: Devuelve los datos de un negocio.
   Parametros:  @negocio_id (entrada)
   Retorna:     negocio_id, nombre, direccion, telefono, email_contacto,
                fecha_registro, estado
   Errores:     50001 no existe
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id)
            THROW 50001, 'El negocio no existe.', 1;

        SELECT negocio_id, nombre, direccion, telefono, email_contacto,
               fecha_registro, estado
        FROM renta.Negocio
        WHERE negocio_id = @negocio_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
