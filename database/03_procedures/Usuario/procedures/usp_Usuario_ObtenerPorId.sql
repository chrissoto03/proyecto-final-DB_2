USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_ObtenerPorId
    @usuario_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_ObtenerPorId
   Descripcion: Devuelve los datos de un usuario. Nunca devuelve el hash de
                la contrasena.
   Parametros:  @usuario_id
   Retorna:     usuario_id, nombre_completo, email, telefono,
                documento_identidad, rol_id, rol, negocio_id, fecha_creacion
   Errores:     50001 no existe
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Usuario WHERE usuario_id = @usuario_id)
            THROW 50001, 'El usuario no existe.', 1;

        SELECT u.usuario_id, u.nombre_completo, u.email, u.telefono,
               u.documento_identidad, u.rol_id, r.nombre AS rol,
               u.negocio_id, u.fecha_creacion
        FROM renta.Usuario u
        INNER JOIN renta.Rol r ON r.rol_id = u.rol_id
        WHERE u.usuario_id = @usuario_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
