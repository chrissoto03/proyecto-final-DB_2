USE RentaTicaDB;
GO

/* ----------------------------------------------------------------------------
   fn_EquipoEstaDisponible
   Descripcion: indica si un equipo puede alquilarse en el rango dado: no esta
                Averiado ni Fuera de servicio y no tiene una reserva activa
                (Pendiente, Confirmada, En curso) que se solape y cuyo equipo
                siga sin devolverse.
   Parametros:  @equipo_id, @fecha_inicio, @fecha_fin
   Retorna:     1 disponible, 0 no disponible
   Autor: <integrante>     Fecha: 2026-10-19
---------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION renta.fn_EquipoEstaDisponible
(
    @equipo_id    INT,
    @fecha_inicio DATETIME,
    @fecha_fin    DATETIME
)
RETURNS BIT
AS
BEGIN
    DECLARE @disponible BIT = 0;

    IF EXISTS (SELECT 1 FROM renta.Equipo
               WHERE equipo_id = @equipo_id
                 AND estado NOT IN ('Averiado', 'Fuera de servicio'))
       AND NOT EXISTS (SELECT 1
                       FROM renta.DetalleReserva dr
                       INNER JOIN renta.Reserva r ON r.reserva_id = dr.reserva_id
                       WHERE dr.equipo_id = @equipo_id
                         AND dr.fecha_hora_devolucion IS NULL
                         AND r.estado IN ('Pendiente', 'Confirmada', 'En curso')
                         AND r.fecha_inicio < @fecha_fin
                         AND r.fecha_fin    > @fecha_inicio)
        SET @disponible = 1;

    RETURN @disponible;
END
GO
