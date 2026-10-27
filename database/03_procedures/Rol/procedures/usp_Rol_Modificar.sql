USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Rol_Modificar
    @rol_id INT,
    @nombre VARCHAR(30)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Rol_Modificar
   Descripcion: Cambia el nombre de un rol. No permite tocar los roles base.
   Parametros:  @rol_id, @nombre (entrada)
   Errores:     50001 no existe; 50003 nombre vacio; 50004 rol base;
                50002 nombre duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50003, 'El nombre del rol es obligatorio.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Rol WHERE rol_id = @rol_id)
            THROW 50001, 'El rol no existe.', 1;

        IF EXISTS (SELECT 1 FROM renta.Rol
                   WHERE rol_id = @rol_id
                     AND nombre IN ('Administrador', 'Operador', 'Cliente'))
            THROW 50004, 'Los roles base del sistema no se pueden modificar.', 1;

        UPDATE renta.Rol SET nombre = LTRIM(RTRIM(@nombre)) WHERE rol_id = @rol_id;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un rol con ese nombre.', 1;
        THROW;
    END CATCH
END
GO
