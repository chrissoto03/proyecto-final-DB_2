USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Mantenimiento_Modificar
    @mantenimiento_id INT,
    @negocio_id       INT,
    @tipo             VARCHAR(20),
    @descripcion      VARCHAR(300) = NULL,
    @costo            DECIMAL(10,2)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Mantenimiento_Modificar
   Descripcion: Corrige tipo, descripcion y costo de un mantenimiento.
   Parametros:  @mantenimiento_id, @negocio_id, @tipo, @descripcion, @costo
   Errores:     50003 datos invalidos; 50001 no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @tipo IS NULL OR @tipo NOT IN ('Preventivo', 'Correctivo')
            THROW 50003, 'El tipo debe ser Preventivo o Correctivo.', 1;
        IF @costo IS NULL OR @costo < 0
            THROW 50003, 'El costo no puede ser negativo.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Mantenimiento m
                       INNER JOIN renta.Equipo e ON e.equipo_id = m.equipo_id
                       INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
                       WHERE m.mantenimiento_id = @mantenimiento_id AND c.negocio_id = @negocio_id)
            THROW 50001, 'El mantenimiento no existe en este negocio.', 1;

        UPDATE renta.Mantenimiento
        SET tipo = @tipo, descripcion = @descripcion, costo = @costo
        WHERE mantenimiento_id = @mantenimiento_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
