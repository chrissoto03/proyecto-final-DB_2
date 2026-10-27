USE RentaTicaDB;
GO

/* ############################################################################
   AUTENTICACION
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Auth_ValidarCredenciales
    @email    VARCHAR(100),
    @password NVARCHAR(100)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Auth_ValidarCredenciales
   Descripcion: Valida correo y contrasena. Si son correctos devuelve los datos
                que el API necesita para firmar el JWT (id, rol, negocio).
                No distingue entre "correo inexistente" y "contrasena
                incorrecta" para no revelar que correos estan registrados.
                Un usuario de un negocio suspendido no puede iniciar sesion.
   Parametros:  @email, @password (texto plano)
   Retorna:     usuario_id, nombre_completo, email, rol, negocio_id
   Errores:     50005 credenciales invalidas; 50004 negocio suspendido
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @usuario_id INT, @almacenado VARCHAR(256), @negocio_id INT;

        SELECT @usuario_id = usuario_id, @almacenado = password_hash, @negocio_id = negocio_id
        FROM renta.Usuario
        WHERE email = @email;

        IF @usuario_id IS NULL OR renta.fn_VerificarPassword(@password, @almacenado) = 0
            THROW 50005, 'Credenciales invalidas.', 1;

        IF @negocio_id IS NOT NULL
           AND EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id AND estado = 'Suspendido')
            THROW 50004, 'El negocio del usuario esta suspendido.', 1;

        SELECT u.usuario_id, u.nombre_completo, u.email, r.nombre AS rol, u.negocio_id
        FROM renta.Usuario u
        INNER JOIN renta.Rol r ON r.rol_id = u.rol_id
        WHERE u.usuario_id = @usuario_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
