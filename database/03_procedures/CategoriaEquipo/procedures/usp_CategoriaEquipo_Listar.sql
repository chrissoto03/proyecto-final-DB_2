USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_CategoriaEquipo_Listar
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_CategoriaEquipo_Listar
   Descripcion: Lista las categorias del negocio con la cantidad de equipos.
   Parametros:  @negocio_id
   Retorna:     categoria_id, nombre, descripcion, tarifa_hora, tarifa_dia,
                monto_deposito, total_equipos
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT c.categoria_id, c.nombre, c.descripcion, c.tarifa_hora, c.tarifa_dia, c.monto_deposito,
               (SELECT COUNT(*) FROM renta.Equipo e WHERE e.categoria_id = c.categoria_id) AS total_equipos
        FROM renta.CategoriaEquipo c
        WHERE c.negocio_id = @negocio_id
        ORDER BY c.nombre;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
