USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_Eliminar
    @usuario_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_Eliminar
   Descripcion: Elimina un usuario que no tenga reservas, mantenimientos ni
                auditoria asociados.
   Parametros:  @usuario_id
   Errores:     50001 no existe; 50002 tiene historial asociado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Usuario WHERE usuario_id = @usuario_id)
            THROW 50001, 'El usuario no existe.', 1;

        IF EXISTS (SELECT 1 FROM renta.Reserva WHERE cliente_id = @usuario_id OR operador_id = @usuario_id)
           OR EXISTS (SELECT 1 FROM renta.Mantenimiento  WHERE operador_id = @usuario_id)
           OR EXISTS (SELECT 1 FROM renta.AuditoriaEquipo WHERE usuario_id  = @usuario_id)
            THROW 50002, 'El usuario tiene historial asociado y no se puede eliminar.', 1;

        DELETE FROM renta.Usuario WHERE usuario_id = @usuario_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
