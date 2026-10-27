USE RentaTicaDB;
GO

/* ############################################################################
   METODO DE PAGO
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_MetodoPago_Crear
    @nombre         VARCHAR(30),
    @metodo_pago_id INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_MetodoPago_Crear
   Descripcion: Registra un nuevo metodo de pago aceptado por la plataforma.
   Parametros:  @nombre (entrada), @metodo_pago_id (salida)
   Errores:     50003 nombre vacio; 50002 nombre duplicado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50003, 'El nombre del metodo de pago es obligatorio.', 1;

        INSERT INTO renta.MetodoPago (nombre) VALUES (LTRIM(RTRIM(@nombre)));
        SET @metodo_pago_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un metodo de pago con ese nombre.', 1;
        THROW;
    END CATCH
END
GO
