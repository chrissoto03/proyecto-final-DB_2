USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Equipo_Modificar
    @equipo_id         INT,
    @negocio_id        INT,
    @categoria_id      INT,
    @codigo_interno    VARCHAR(20),
    @descripcion       VARCHAR(200) = NULL,
    @notas             VARCHAR(300) = NULL,
    @fecha_adquisicion DATE = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Equipo_Modificar
   Descripcion: Actualiza los datos de un equipo (no su estado: para eso esta
                usp_Equipo_ActualizarEstado). La categoria nueva debe ser del
                mismo negocio.
   Parametros:  @equipo_id, @negocio_id y los datos nuevos
   Errores:     50003 datos invalidos; 50001 equipo o categoria inexistente en
                el negocio; 50002 codigo repetido
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @codigo_interno IS NULL OR LTRIM(RTRIM(@codigo_interno)) = ''
            THROW 50003, 'El codigo interno es obligatorio.', 1;
        IF @fecha_adquisicion IS NOT NULL AND @fecha_adquisicion > CAST(GETDATE() AS DATE)
            THROW 50003, 'La fecha de adquisicion no puede ser futura.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Equipo e
                       INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
                       WHERE e.equipo_id = @equipo_id AND c.negocio_id = @negocio_id)
            THROW 50001, 'El equipo no existe en este negocio.', 1;
        IF NOT EXISTS (SELECT 1 FROM renta.CategoriaEquipo
                       WHERE categoria_id = @categoria_id AND negocio_id = @negocio_id)
            THROW 50001, 'La categoria no existe en este negocio.', 1;
        IF EXISTS (SELECT 1 FROM renta.Equipo e
                   INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
                   WHERE c.negocio_id = @negocio_id
                     AND e.codigo_interno = LTRIM(RTRIM(@codigo_interno))
                     AND e.equipo_id <> @equipo_id)
            THROW 50002, 'Ya existe otro equipo con ese codigo en el negocio.', 1;

        UPDATE renta.Equipo
        SET categoria_id = @categoria_id, codigo_interno = LTRIM(RTRIM(@codigo_interno)),
            descripcion = @descripcion, notas = @notas, fecha_adquisicion = @fecha_adquisicion
        WHERE equipo_id = @equipo_id;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2601, 2627)
            THROW 50002, 'Ya existe un equipo con ese codigo.', 1;
        THROW;
    END CATCH
END
GO
