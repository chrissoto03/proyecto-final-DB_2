USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Equipo_ConsultarDisponibilidad
    @negocio_id   INT,
    @categoria_id INT = NULL,
    @fecha_inicio DATETIME,
    @fecha_fin    DATETIME
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Equipo_ConsultarDisponibilidad
   Descripcion: Lista los equipos libres del negocio en un rango de fechas,
                con el monto estimado de alquilarlos en ese rango. Usa
                fn_EquiposDisponibles y fn_CalcularMontoAlquiler.
   Parametros:  @negocio_id, @categoria_id (NULL = todas), @fecha_inicio, @fecha_fin
   Retorna:     equipo_id, codigo_interno, descripcion, categoria_id, categoria,
                tarifa_hora, tarifa_dia, monto_deposito, monto_estimado
   Errores:     50003 rango invalido; 50001 negocio inexistente
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @fecha_inicio IS NULL OR @fecha_fin IS NULL OR @fecha_fin <= @fecha_inicio
            THROW 50003, 'El rango de fechas es invalido: la fecha final debe ser posterior a la inicial.', 1;
        IF NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id)
            THROW 50001, 'El negocio no existe.', 1;

        SELECT d.equipo_id, d.codigo_interno, d.descripcion, d.categoria_id, d.categoria,
               d.tarifa_hora, d.tarifa_dia, d.monto_deposito,
               renta.fn_CalcularMontoAlquiler(d.tarifa_hora, d.tarifa_dia, @fecha_inicio, @fecha_fin) AS monto_estimado
        FROM renta.fn_EquiposDisponibles(@negocio_id, @categoria_id, @fecha_inicio, @fecha_fin) d
        ORDER BY d.categoria, d.codigo_interno;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
