USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_CambiarRol
    @usuario_id INT,
    @rol_id     INT,
    @negocio_id INT = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_CambiarRol
   Descripcion: Cambia el rol (y el negocio) de un usuario respetando la regla
                multi-tenant. No permite convertir en personal a quien tiene
                reservas como cliente, ni en cliente a quien tiene historial
                como operador.
   Parametros:  @usuario_id, @rol_id, @negocio_id
   Errores:     50001 usuario/rol/negocio inexistente; 50003 combinacion
                rol-negocio invalida; 50004 el usuario tiene historial
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Usuario WHERE usuario_id = @usuario_id)
            THROW 50001, 'El usuario no existe.', 1;
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

        IF @requiere = 1
           AND EXISTS (SELECT 1 FROM renta.Reserva WHERE cliente_id = @usuario_id)
            THROW 50004, 'El usuario tiene reservas como cliente; no puede pasar a ser personal.', 1;

        IF @requiere = 0
           AND (EXISTS (SELECT 1 FROM renta.Reserva       WHERE operador_id = @usuario_id)
             OR EXISTS (SELECT 1 FROM renta.Mantenimiento WHERE operador_id = @usuario_id))
            THROW 50004, 'El usuario tiene historial como personal; no puede pasar a ser cliente.', 1;

        UPDATE renta.Usuario
        SET rol_id = @rol_id, negocio_id = @negocio_id
        WHERE usuario_id = @usuario_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
