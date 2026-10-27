USE RentaTicaDB;
GO

/* ############################################################################
   AUDITORIA EQUIPO (solo lectura: la llena el trigger del script 10)
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_AuditoriaEquipo_ListarPorEquipo
    @equipo_id  INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_AuditoriaEquipo_ListarPorEquipo
   Descripcion: Bitacora de cambios de estado de un equipo, del mas reciente al
                mas antiguo.
   Parametros:  @equipo_id, @negocio_id
   Errores:     50001 el equipo no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Equipo e
                       INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
                       WHERE e.equipo_id = @equipo_id AND c.negocio_id = @negocio_id)
            THROW 50001, 'El equipo no existe en este negocio.', 1;

        SELECT a.auditoria_id, a.equipo_id, a.estado_anterior, a.estado_nuevo, a.fecha_hora,
               a.usuario_id, u.nombre_completo AS usuario
        FROM renta.AuditoriaEquipo a
        LEFT JOIN renta.Usuario u ON u.usuario_id = a.usuario_id
        WHERE a.equipo_id = @equipo_id
        ORDER BY a.fecha_hora DESC, a.auditoria_id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
