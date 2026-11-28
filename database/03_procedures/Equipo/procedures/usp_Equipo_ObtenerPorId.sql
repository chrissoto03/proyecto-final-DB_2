USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Equipo_ObtenerPorId
    @equipo_id  INT,
    @negocio_id INT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Equipo_ObtenerPorId
   Descripcion: Devuelve un equipo con los datos y tarifas de su categoria.
   Parametros:  @equipo_id, @negocio_id
   Errores:     50001 no existe en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM renta.Equipo e
                       INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
                       WHERE e.equipo_id = @equipo_id AND c.negocio_id = @negocio_id)
            THROW 50001, 'El equipo no existe en este negocio.', 1;

        SELECT e.equipo_id, e.codigo_interno, e.descripcion, e.estado, e.notas, e.fecha_adquisicion,
               c.categoria_id, c.nombre AS categoria, c.tarifa_hora, c.tarifa_dia, c.monto_deposito
        FROM renta.Equipo e
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE e.equipo_id = @equipo_id;
        SELECT r.reserva_id,r.estado,r.fecha_inicio,r.fecha_fin,u.nombre_completo AS cliente
        FROM renta.DetalleReserva d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id
        JOIN renta.Usuario u ON u.usuario_id=r.cliente_id
        WHERE d.equipo_id=@equipo_id AND r.negocio_id=@negocio_id
          AND r.estado IN ('Pendiente','Confirmada','En curso') AND d.fecha_hora_devolucion IS NULL
        ORDER BY r.fecha_inicio;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
