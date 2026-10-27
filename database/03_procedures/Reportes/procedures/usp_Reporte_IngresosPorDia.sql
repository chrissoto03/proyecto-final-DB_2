USE RentaTicaDB;
GO

/* Nombre: usp_Reporte_IngresosPorDia
   Descripcion: Agrupa los pagos completados por dia
   Parametros: @negocio_id, @desde, @hasta
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reporte_IngresosPorDia
 @negocio_id INT,@desde DATE,@hasta DATE
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 IF @desde IS NULL OR @hasta IS NULL OR @hasta<@desde THROW 50003,'Rango de fechas invalido.',1;
 SELECT CONVERT(date,p.fecha_pago) AS fecha,COUNT(*) AS pagos,SUM(p.monto) AS ingresos
 FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id
 WHERE r.negocio_id=@negocio_id AND p.estado='Completado'
   AND p.fecha_pago>=@desde AND p.fecha_pago<DATEADD(DAY,1,@hasta)
 GROUP BY CONVERT(date,p.fecha_pago) ORDER BY fecha;
END TRY BEGIN CATCH THROW; END CATCH END
GO
