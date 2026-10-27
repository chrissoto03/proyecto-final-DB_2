USE RentaTicaDB;
GO

/* Nombre: usp_Reporte_ClientesFrecuentes
   Descripcion: Ordena clientes por reservas y alquiler completado
   Parametros: @negocio_id, @desde, @hasta
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reporte_ClientesFrecuentes
 @negocio_id INT,@desde DATE=NULL,@hasta DATE=NULL
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT u.usuario_id,u.nombre_completo,COUNT(*) AS reservas,
        SUM(CASE WHEN r.estado='Completada' THEN r.monto_final ELSE 0 END) AS alquiler_completado
 FROM renta.Reserva r JOIN renta.Usuario u ON u.usuario_id=r.cliente_id
 WHERE r.negocio_id=@negocio_id AND r.estado<>'Cancelada'
  AND (@desde IS NULL OR r.fecha_reserva>=@desde) AND (@hasta IS NULL OR r.fecha_reserva<DATEADD(DAY,1,@hasta))
 GROUP BY u.usuario_id,u.nombre_completo ORDER BY reservas DESC,alquiler_completado DESC;
END TRY BEGIN CATCH THROW; END CATCH END
GO
