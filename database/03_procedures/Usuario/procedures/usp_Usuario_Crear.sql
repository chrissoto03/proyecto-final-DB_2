USE RentaTicaDB;
GO

/* ############################################################################
   USUARIO
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Usuario_Crear
    @nombre_completo     VARCHAR(100),
    @email               VARCHAR(100),
    @password            NVARCHAR(100),
    @telefono            VARCHAR(20) = NULL,
    @documento_identidad VARCHAR(30) = NULL,
    @rol_id              INT,
    @negocio_id          INT = NULL,
    @usuario_id          INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_Crear
   Descripcion: Crea un usuario aplicando todas las reglas: correo valido,
                contrasena de al menos 8 caracteres y la regla multi-tenant
                (el personal pertenece a un negocio; el cliente no).
   Parametros:  datos del usuario (entrada), @usuario_id (salida)
   Errores:     50003 datos invalidos; 50001 rol o negocio inexistente;
                50002 correo duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre_completo IS NULL OR LTRIM(RTRIM(@nombre_completo)) = ''
            THROW 50003, 'El nombre completo es obligatorio.', 1;
        IF @email IS NULL OR @email NOT LIKE '%_@_%._%'
            THROW 50003, 'El correo no tiene un formato valido.', 1;
        IF @password IS NULL OR LEN(@password) < 8
            THROW 50003, 'La contrasena debe tener al menos 8 caracteres.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Rol WHERE rol_id = @rol_id)
            THROW 50001, 'El rol no existe.', 1;

        DECLARE @requiere BIT = renta.fn_RolRequiereNegocio(@rol_id);

        IF @requiere = 1 AND @negocio_id IS NULL
            THROW 50003, 'Este rol debe pertenecer a un negocio.', 1;
        IF @requiere = 0 AND @negocio_id IS NOT NULL
            THROW 50003, 'Un cliente no puede pertenecer a un negocio.', 1;
        IF @negocio_id IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id)
            THROW 50001, 'El negocio no existe.', 1;

        DECLARE @salt VARCHAR(32) = CONVERT(VARCHAR(32), CRYPT_GEN_RANDOM(16), 2);

        INSERT INTO renta.Usuario
            (nombre_completo, email, password_hash, telefono, documento_identidad, rol_id, negocio_id)
        VALUES
            (LTRIM(RTRIM(@nombre_completo)), LTRIM(RTRIM(@email)),
             renta.fn_HashPassword(@password, @salt),
             @telefono, @documento_identidad, @rol_id, @negocio_id);

        SET @usuario_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un usuario con ese correo.', 1;
        THROW;
    END CATCH
END
GO
