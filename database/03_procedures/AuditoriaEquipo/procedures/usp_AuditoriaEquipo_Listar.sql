USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_AuditoriaEquipo_Listar
    @negocio_id INT,
    @desde      DATETIME = NULL,
    @hasta      DATETIME = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_AuditoriaEquipo_Listar
   Descripcion: Bitacora de cambios de estado de todos los equipos del negocio
                en un rango de fechas [desde, hasta).
   Parametros:  @negocio_id, @desde, @hasta
   Errores:     50003 rango invalido
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @desde IS NOT NULL AND @hasta IS NOT NULL AND @hasta <= @desde
            THROW 50003, 'El rango de fechas es invalido.', 1;

        SELECT a.auditoria_id, a.equipo_id, e.codigo_interno, a.estado_anterior, a.estado_nuevo,
               a.fecha_hora, a.usuario_id, u.nombre_completo AS usuario
        FROM renta.AuditoriaEquipo a
        INNER JOIN renta.Equipo e ON e.equipo_id = a.equipo_id
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        LEFT JOIN renta.Usuario u ON u.usuario_id = a.usuario_id
        WHERE c.negocio_id = @negocio_id
          AND (@desde IS NULL OR a.fecha_hora >= @desde)
          AND (@hasta IS NULL OR a.fecha_hora <  @hasta)
        ORDER BY a.fecha_hora DESC, a.auditoria_id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
