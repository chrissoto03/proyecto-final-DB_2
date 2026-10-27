USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_Modificar
    @usuario_id          INT,
    @nombre_completo     VARCHAR(100),
    @email               VARCHAR(100),
    @telefono            VARCHAR(20) = NULL,
    @documento_identidad VARCHAR(30) = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_Modificar
   Descripcion: Actualiza los datos personales. No cambia contrasena ni rol
                (existen SPs especificos para eso).
   Parametros:  @usuario_id, @nombre_completo, @email, @telefono,
                @documento_identidad
   Errores:     50001 no existe; 50003 datos invalidos; 50002 correo duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre_completo IS NULL OR LTRIM(RTRIM(@nombre_completo)) = ''
            THROW 50003, 'El nombre completo es obligatorio.', 1;
        IF @email IS NULL OR @email NOT LIKE '%_@_%._%'
            THROW 50003, 'El correo no tiene un formato valido.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Usuario WHERE usuario_id = @usuario_id)
            THROW 50001, 'El usuario no existe.', 1;

        UPDATE renta.Usuario
        SET nombre_completo     = LTRIM(RTRIM(@nombre_completo)),
            email               = LTRIM(RTRIM(@email)),
            telefono            = @telefono,
            documento_identidad = @documento_identidad
        WHERE usuario_id = @usuario_id;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un usuario con ese correo.', 1;
        THROW;
    END CATCH
END
GO
