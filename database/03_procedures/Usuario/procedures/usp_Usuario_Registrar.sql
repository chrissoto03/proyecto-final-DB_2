USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_Registrar
    @nombre_completo     VARCHAR(100),
    @email               VARCHAR(100),
    @password            NVARCHAR(100),
    @telefono            VARCHAR(20) = NULL,
    @documento_identidad VARCHAR(30) = NULL,
    @usuario_id          INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_Registrar
   Descripcion: Autorregistro publico de un Cliente (turista). El rol queda
                fijo en Cliente y no tiene negocio.
   Parametros:  datos del cliente (entrada), @usuario_id (salida)
   Errores:     los de usp_Usuario_Crear
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @rol_cliente INT = (SELECT rol_id FROM renta.Rol WHERE nombre = 'Cliente');

        EXEC renta.usp_Usuario_Crear
            @nombre_completo     = @nombre_completo,
            @email               = @email,
            @password            = @password,
            @telefono            = @telefono,
            @documento_identidad = @documento_identidad,
            @rol_id              = @rol_cliente,
            @negocio_id          = NULL,
            @usuario_id          = @usuario_id OUTPUT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
