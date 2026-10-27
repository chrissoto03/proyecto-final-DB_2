USE RentaTicaDB;
GO

/* Nombre: usp_Reporte_MantenimientoCostos
   Descripcion: Agrupa trabajos y costos de mantenimiento
   Parametros: @negocio_id, @desde, @hasta
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reporte_MantenimientoCostos
 @negocio_id INT,@desde DATE=NULL,@hasta DATE=NULL
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT m.tipo,COUNT(*) AS trabajos,SUM(m.costo) AS costo_total
 FROM renta.Mantenimiento m JOIN renta.Equipo e ON e.equipo_id=m.equipo_id
 JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
 WHERE c.negocio_id=@negocio_id AND (@desde IS NULL OR m.fecha_inicio>=@desde)
  AND (@hasta IS NULL OR m.fecha_inicio<=@hasta)
 GROUP BY m.tipo ORDER BY m.tipo;
END TRY BEGIN CATCH THROW; END CATCH END
GO
