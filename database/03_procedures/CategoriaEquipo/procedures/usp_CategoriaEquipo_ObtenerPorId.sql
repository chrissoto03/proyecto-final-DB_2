USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_CategoriaEquipo_ObtenerPorId
    @categoria_id INT,
    @negocio_id   INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_CategoriaEquipo_ObtenerPorId
   Descripcion: Devuelve una categoria del negocio.
   Parametros:  @categoria_id, @negocio_id
   Retorna:     categoria_id, negocio_id, nombre, descripcion, tarifa_hora,
                tarifa_dia, monto_deposito
   Errores:     50001 no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.CategoriaEquipo
                       WHERE categoria_id = @categoria_id AND negocio_id = @negocio_id)
            THROW 50001, 'La categoria no existe en este negocio.', 1;

        SELECT categoria_id, negocio_id, nombre, descripcion, tarifa_hora, tarifa_dia, monto_deposito
        FROM renta.CategoriaEquipo
        WHERE categoria_id = @categoria_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
