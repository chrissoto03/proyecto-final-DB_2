USE RentaTicaDB;
GO

/* ----------------------------------------------------------------------------
   fn_EquiposDisponibles  (funcion de tabla en linea)
   Descripcion: equipos de un negocio disponibles en un rango, con las tarifas
                de su categoria. Misma regla que fn_EquipoEstaDisponible.
   Parametros:  @negocio_id, @categoria_id (NULL = todas), @fecha_inicio, @fecha_fin
   Retorna:     equipo_id, codigo_interno, descripcion, estado, categoria_id,
                categoria, tarifa_hora, tarifa_dia, monto_deposito
   Autor: <integrante>     Fecha: 2026-10-19
---------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION renta.fn_EquiposDisponibles
(
    @negocio_id   INT,
    @categoria_id INT,
    @fecha_inicio DATETIME,
    @fecha_fin    DATETIME
)
RETURNS TABLE
AS
RETURN
(
    SELECT e.equipo_id, e.codigo_interno, e.descripcion, e.estado,
           c.categoria_id, c.nombre AS categoria,
           c.tarifa_hora, c.tarifa_dia, c.monto_deposito
    FROM renta.Equipo e
    INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
    WHERE c.negocio_id = @negocio_id
      AND (@categoria_id IS NULL OR e.categoria_id = @categoria_id)
      AND e.estado NOT IN ('Averiado', 'Fuera de servicio')
      AND NOT EXISTS (SELECT 1
                      FROM renta.DetalleReserva dr
                      INNER JOIN renta.Reserva r ON r.reserva_id = dr.reserva_id
                      WHERE dr.equipo_id = e.equipo_id
                        AND dr.fecha_hora_devolucion IS NULL
                        AND r.estado IN ('Pendiente', 'Confirmada', 'En curso')
                        AND r.fecha_inicio < @fecha_fin
                        AND r.fecha_fin    > @fecha_inicio)
);
GO
