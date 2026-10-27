USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Equipo_Eliminar
    @equipo_id  INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Equipo_Eliminar
   Descripcion: Elimina un equipo que nunca se haya alquilado, mantenido ni
                auditado. Si tiene historial, debe marcarse Fuera de servicio.
   Parametros:  @equipo_id, @negocio_id
   Errores:     50001 no existe en el negocio; 50002 tiene historial
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Equipo e
                       INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
                       WHERE e.equipo_id = @equipo_id AND c.negocio_id = @negocio_id)
            THROW 50001, 'El equipo no existe en este negocio.', 1;

        IF EXISTS (SELECT 1 FROM renta.DetalleReserva  WHERE equipo_id = @equipo_id)
           OR EXISTS (SELECT 1 FROM renta.Mantenimiento   WHERE equipo_id = @equipo_id)
           OR EXISTS (SELECT 1 FROM renta.AuditoriaEquipo WHERE equipo_id = @equipo_id)
            THROW 50002, 'El equipo tiene historial. Marquelo como Fuera de servicio en lugar de eliminarlo.', 1;

        DELETE FROM renta.Equipo WHERE equipo_id = @equipo_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
