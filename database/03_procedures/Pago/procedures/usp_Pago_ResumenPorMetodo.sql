USE RentaTicaDB;
GO

/* Nombre: usp_Pago_ResumenPorMetodo
   Descripcion: Resume montos cobrados por metodo de pago y periodo
   Parametros: @negocio_id, @desde, @hasta
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Pago_ResumenPorMetodo
 @negocio_id INT,@desde DATETIME=NULL,@hasta DATETIME=NULL
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 IF @desde IS NOT NULL AND @hasta IS NOT NULL AND @hasta<=@desde THROW 50003,'Rango de fechas invalido.',1;
 SELECT m.metodo_pago_id,m.nombre AS metodo_pago,COUNT(*) AS cantidad_pagos,SUM(p.monto) AS monto_total
 FROM renta.Pago p JOIN renta.MetodoPago m ON m.metodo_pago_id=p.metodo_pago_id
 JOIN renta.Reserva r ON r.reserva_id=p.reserva_id
 WHERE r.negocio_id=@negocio_id AND p.estado='Completado'
   AND (@desde IS NULL OR p.fecha_pago>=@desde) AND (@hasta IS NULL OR p.fecha_pago<@hasta)
 GROUP BY m.metodo_pago_id,m.nombre ORDER BY monto_total DESC;
END TRY BEGIN CATCH THROW; END CATCH END
GO
