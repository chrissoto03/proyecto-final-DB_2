USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_CambiarPassword
    @usuario_id     INT,
    @password_actual NVARCHAR(100),
    @password_nueva  NVARCHAR(100)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_CambiarPassword
   Descripcion: Cambia la contrasena verificando primero la actual. Genera un
                salt nuevo.
   Parametros:  @usuario_id, @password_actual, @password_nueva
   Errores:     50001 no existe; 50003 contrasena nueva invalida o igual a la
                actual; 50005 contrasena actual incorrecta
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @almacenado VARCHAR(256) =
            (SELECT password_hash FROM renta.Usuario WHERE usuario_id = @usuario_id);

        IF @almacenado IS NULL
            THROW 50001, 'El usuario no existe.', 1;

        IF renta.fn_VerificarPassword(@password_actual, @almacenado) = 0
            THROW 50005, 'La contrasena actual es incorrecta.', 1;

        IF @password_nueva IS NULL OR LEN(@password_nueva) < 8
            THROW 50003, 'La contrasena nueva debe tener al menos 8 caracteres.', 1;
        IF @password_nueva = @password_actual
            THROW 50003, 'La contrasena nueva debe ser distinta de la actual.', 1;

        DECLARE @salt VARCHAR(32) = CONVERT(VARCHAR(32), CRYPT_GEN_RANDOM(16), 2);

        UPDATE renta.Usuario
        SET password_hash = renta.fn_HashPassword(@password_nueva, @salt)
        WHERE usuario_id = @usuario_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
