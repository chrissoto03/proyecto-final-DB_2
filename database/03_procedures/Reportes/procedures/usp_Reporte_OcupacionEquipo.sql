USE RentaTicaDB;
GO

/* Nombre: usp_Reporte_OcupacionEquipo
   Descripcion: Calcula minutos reservados por equipo en un rango
   Parametros: @negocio_id, @desde, @hasta
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reporte_OcupacionEquipo
 @negocio_id INT,@desde DATETIME,@hasta DATETIME
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 IF @desde IS NULL OR @hasta<=@desde THROW 50003,'Rango de fechas invalido.',1;
 SELECT e.equipo_id,e.codigo_interno,c.nombre AS categoria,
        COUNT(DISTINCT r.reserva_id) AS reservas_en_rango,
        SUM(CASE WHEN r.reserva_id IS NULL THEN 0 ELSE DATEDIFF(MINUTE,
             CASE WHEN r.fecha_inicio<@desde THEN @desde ELSE r.fecha_inicio END,
             CASE WHEN r.fecha_fin>@hasta THEN @hasta ELSE r.fecha_fin END) END) AS minutos_reservados
 FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
 LEFT JOIN renta.DetalleReserva d ON d.equipo_id=e.equipo_id
 LEFT JOIN renta.Reserva r ON r.reserva_id=d.reserva_id AND r.estado IN('Pendiente','Confirmada','En curso')
  AND r.fecha_inicio<@hasta AND r.fecha_fin>@desde
 WHERE c.negocio_id=@negocio_id GROUP BY e.equipo_id,e.codigo_interno,c.nombre
 ORDER BY minutos_reservados DESC,e.codigo_interno;
END TRY BEGIN CATCH THROW; END CATCH END
GO
