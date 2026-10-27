USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Mantenimiento_Listar
    @negocio_id    INT,
    @equipo_id     INT = NULL,
    @solo_abiertos BIT = 0
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Mantenimiento_Listar
   Descripcion: Lista los mantenimientos del negocio, mas recientes primero.
   Parametros:  @negocio_id, @equipo_id (NULL = todos), @solo_abiertos
                (1 = solo los que siguen en curso)
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT m.mantenimiento_id, m.equipo_id, e.codigo_interno, m.tipo, m.descripcion, m.costo,
               m.fecha_inicio, m.fecha_fin, m.operador_id, u.nombre_completo AS operador,
               CASE WHEN m.fecha_fin IS NULL THEN 'En curso' ELSE 'Finalizado' END AS situacion
        FROM renta.Mantenimiento m
        INNER JOIN renta.Equipo e ON e.equipo_id = m.equipo_id
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        LEFT JOIN renta.Usuario u ON u.usuario_id = m.operador_id
        WHERE c.negocio_id = @negocio_id
          AND (@equipo_id IS NULL OR m.equipo_id = @equipo_id)
          AND (@solo_abiertos = 0 OR m.fecha_fin IS NULL)
        ORDER BY m.fecha_inicio DESC, m.mantenimiento_id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
