USE RentaTicaDB;
GO

/* ############################################################################
   ROL
   Los 3 roles base (Administrador, Operador, Cliente) estan protegidos: no se
   pueden modificar ni eliminar, porque la logica del sistema depende de ellos.
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Rol_Crear
    @nombre VARCHAR(30),
    @rol_id INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Rol_Crear
   Descripcion: Crea un rol nuevo en el catalogo de roles.
   Parametros:  @nombre (entrada), @rol_id (salida: id generado)
   Errores:     50003 nombre vacio; 50002 nombre duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50003, 'El nombre del rol es obligatorio.', 1;

        INSERT INTO renta.Rol (nombre) VALUES (LTRIM(RTRIM(@nombre)));
        SET @rol_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un rol con ese nombre.', 1;
        THROW;
    END CATCH
END
GO
