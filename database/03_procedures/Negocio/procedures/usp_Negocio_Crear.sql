USE RentaTicaDB;
GO

/* ############################################################################
   NEGOCIO (tenant de la plataforma)
   La baja normal de un negocio es suspenderlo (CambiarEstado), para conservar
   su historial. Eliminar solo procede si el negocio no tiene nada asociado.
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Negocio_Crear
    @nombre         VARCHAR(100),
    @direccion      VARCHAR(200) = NULL,
    @telefono       VARCHAR(20)  = NULL,
    @email_contacto VARCHAR(100),
    @negocio_id     INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Negocio_Crear
   Descripcion: Registra un negocio nuevo (tenant) en la plataforma, en estado
                Activo.
   Parametros:  @nombre, @direccion, @telefono, @email_contacto (entrada),
                @negocio_id (salida)
   Errores:     50003 nombre o correo vacios; 50002 correo duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50003, 'El nombre del negocio es obligatorio.', 1;
        IF @email_contacto IS NULL OR LTRIM(RTRIM(@email_contacto)) = ''
            THROW 50003, 'El correo de contacto es obligatorio.', 1;

        INSERT INTO renta.Negocio (nombre, direccion, telefono, email_contacto)
        VALUES (LTRIM(RTRIM(@nombre)), @direccion, @telefono, LTRIM(RTRIM(@email_contacto)));

        SET @negocio_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un negocio con ese correo de contacto.', 1;
        THROW;
    END CATCH
END
GO
