USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_Listar
    @negocio_id INT = NULL,
    @rol_id     INT = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_Listar
   Descripcion: Lista usuarios con filtros opcionales por negocio y por rol.
                Un Administrador lo usa con su @negocio_id para ver su personal.
   Parametros:  @negocio_id (NULL = todos), @rol_id (NULL = todos)
   Retorna:     usuario_id, nombre_completo, email, telefono, rol, negocio_id,
                fecha_creacion
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT u.usuario_id, u.nombre_completo, u.email, u.telefono,
               r.nombre AS rol, u.negocio_id, u.fecha_creacion
        FROM renta.Usuario u
        INNER JOIN renta.Rol r ON r.rol_id = u.rol_id
        WHERE (@negocio_id IS NULL OR u.negocio_id = @negocio_id)
          AND (@rol_id     IS NULL OR u.rol_id     = @rol_id)
        ORDER BY u.nombre_completo;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
