USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Mantenimiento_Eliminar
    @mantenimiento_id INT,
    @negocio_id       INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Mantenimiento_Eliminar
   Descripcion: Elimina un registro de mantenimiento ya finalizado. Uno abierto
                no se puede eliminar porque dejaria el equipo trabado en
                estado Mantenimiento.
   Parametros:  @mantenimiento_id, @negocio_id
   Errores:     50001 no existe en el negocio; 50004 sigue abierto
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
        IF EXISTS (SELECT 1 FROM renta.Mantenimiento
                   WHERE mantenimiento_id = @mantenimiento_id AND fecha_fin IS NULL)
            THROW 50004, 'El mantenimiento sigue abierto. Finalicelo antes de eliminarlo.', 1;

        DELETE FROM renta.Mantenimiento WHERE mantenimiento_id = @mantenimiento_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
