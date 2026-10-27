USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Negocio_Listar
    @estado VARCHAR(20) = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Negocio_Listar
   Descripcion: Lista los negocios de la plataforma, con filtro opcional por
                estado.
   Parametros:  @estado (opcional: 'Activo' o 'Suspendido'; NULL = todos)
   Retorna:     negocio_id, nombre, direccion, telefono, email_contacto,
                fecha_registro, estado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT negocio_id, nombre, direccion, telefono, email_contacto,
               fecha_registro, estado
        FROM renta.Negocio
        WHERE @estado IS NULL OR estado = @estado
        ORDER BY nombre;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
