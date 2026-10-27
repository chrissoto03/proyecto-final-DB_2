USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Usuario_CrearEmpleado
    @nombre_completo VARCHAR(100),
    @email           VARCHAR(100),
    @password        NVARCHAR(100),
    @telefono        VARCHAR(20) = NULL,
    @rol_nombre      VARCHAR(30),
    @negocio_id      INT,
    @usuario_id      INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Usuario_CrearEmpleado
   Descripcion: Da de alta personal de un negocio. Solo permite los roles
                Administrador y Operador.
   Parametros:  datos del empleado, @rol_nombre ('Administrador' u 'Operador'),
                @negocio_id (entrada); @usuario_id (salida)
   Errores:     50003 rol no permitido; los de usp_Usuario_Crear
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @rol_nombre IS NULL OR @rol_nombre NOT IN ('Administrador', 'Operador')
            THROW 50003, 'El rol debe ser Administrador u Operador.', 1;

        DECLARE @rol_id INT = (SELECT rol_id FROM renta.Rol WHERE nombre = @rol_nombre);

        EXEC renta.usp_Usuario_Crear
            @nombre_completo = @nombre_completo,
            @email           = @email,
            @password        = @password,
            @telefono        = @telefono,
            @rol_id          = @rol_id,
            @negocio_id      = @negocio_id,
            @usuario_id      = @usuario_id OUTPUT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
