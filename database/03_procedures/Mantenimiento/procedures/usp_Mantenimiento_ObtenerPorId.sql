USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Mantenimiento_ObtenerPorId
    @mantenimiento_id INT,
    @negocio_id       INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Mantenimiento_ObtenerPorId
   Descripcion: Devuelve un mantenimiento con el equipo y el operador.
   Parametros:  @mantenimiento_id, @negocio_id
   Errores:     50001 no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Mantenimiento m
                       INNER JOIN renta.Equipo e ON e.equipo_id = m.equipo_id
                       INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
                       WHERE m.mantenimiento_id = @mantenimiento_id AND c.negocio_id = @negocio_id)
            THROW 50001, 'El mantenimiento no existe en este negocio.', 1;

        SELECT m.mantenimiento_id, m.equipo_id, e.codigo_interno, m.tipo, m.descripcion, m.costo,
               m.fecha_inicio, m.fecha_fin, m.operador_id, u.nombre_completo AS operador,
               CASE WHEN m.fecha_fin IS NULL THEN 'En curso' ELSE 'Finalizado' END AS situacion
        FROM renta.Mantenimiento m
        INNER JOIN renta.Equipo e ON e.equipo_id = m.equipo_id
        LEFT JOIN renta.Usuario u ON u.usuario_id = m.operador_id
        WHERE m.mantenimiento_id = @mantenimiento_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
