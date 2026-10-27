USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Equipo_Listar
    @negocio_id   INT,
    @categoria_id INT = NULL,
    @estado       VARCHAR(20) = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Equipo_Listar
   Descripcion: Lista los equipos del negocio, con filtros opcionales por
                categoria y por estado.
   Parametros:  @negocio_id, @categoria_id (NULL = todas), @estado (NULL = todos)
   Retorna:     equipo_id, codigo_interno, descripcion, estado, notas,
                fecha_adquisicion, categoria_id, categoria, tarifa_hora, tarifa_dia
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT e.equipo_id, e.codigo_interno, e.descripcion, e.estado, e.notas, e.fecha_adquisicion,
               c.categoria_id, c.nombre AS categoria, c.tarifa_hora, c.tarifa_dia
        FROM renta.Equipo e
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE c.negocio_id = @negocio_id
          AND (@categoria_id IS NULL OR e.categoria_id = @categoria_id)
          AND (@estado       IS NULL OR e.estado       = @estado)
        ORDER BY c.nombre, e.codigo_interno;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
