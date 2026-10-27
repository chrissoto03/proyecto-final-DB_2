USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Negocio_Modificar
    @negocio_id     INT,
    @nombre         VARCHAR(100),
    @direccion      VARCHAR(200) = NULL,
    @telefono       VARCHAR(20)  = NULL,
    @email_contacto VARCHAR(100)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Negocio_Modificar
   Descripcion: Actualiza los datos generales de un negocio. No cambia el
                estado (para eso esta usp_Negocio_CambiarEstado).
   Parametros:  @negocio_id, @nombre, @direccion, @telefono, @email_contacto
   Errores:     50001 no existe; 50003 datos vacios; 50002 correo duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50003, 'El nombre del negocio es obligatorio.', 1;
        IF @email_contacto IS NULL OR LTRIM(RTRIM(@email_contacto)) = ''
            THROW 50003, 'El correo de contacto es obligatorio.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id)
            THROW 50001, 'El negocio no existe.', 1;

        UPDATE renta.Negocio
        SET nombre         = LTRIM(RTRIM(@nombre)),
            direccion      = @direccion,
            telefono       = @telefono,
            email_contacto = LTRIM(RTRIM(@email_contacto))
        WHERE negocio_id = @negocio_id;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un negocio con ese correo de contacto.', 1;
        THROW;
    END CATCH
END
GO
