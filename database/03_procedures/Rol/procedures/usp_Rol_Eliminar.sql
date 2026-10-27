USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Rol_Eliminar
    @rol_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Rol_Eliminar
   Descripcion: Elimina un rol que no sea base y que no tenga usuarios.
   Parametros:  @rol_id (entrada)
   Errores:     50001 no existe; 50004 rol base; 50002 tiene usuarios
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Rol WHERE rol_id = @rol_id)
            THROW 50001, 'El rol no existe.', 1;

        IF EXISTS (SELECT 1 FROM renta.Rol
                   WHERE rol_id = @rol_id
                     AND nombre IN ('Administrador', 'Operador', 'Cliente'))
            THROW 50004, 'Los roles base del sistema no se pueden eliminar.', 1;

        IF EXISTS (SELECT 1 FROM renta.Usuario WHERE rol_id = @rol_id)
            THROW 50002, 'No se puede eliminar: hay usuarios con este rol.', 1;

        DELETE FROM renta.Rol WHERE rol_id = @rol_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
