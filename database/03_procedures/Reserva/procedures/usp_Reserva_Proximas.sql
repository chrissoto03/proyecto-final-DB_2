USE RentaTicaDB;
GO

/* Nombre: usp_Reserva_Proximas
   Descripcion: Lista reservas futuras dentro de un horizonte de dias
   Parametros: @negocio_id, @dias
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reserva_Proximas @negocio_id INT,@dias INT=7
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 IF @dias<0 OR @dias>365 THROW 50003,'El numero de dias debe estar entre 0 y 365.',1;
 SELECT r.reserva_id,r.estado,r.tipo_reserva,r.fecha_inicio,r.fecha_fin,u.nombre_completo AS cliente,
        (SELECT COUNT(*) FROM renta.DetalleReserva d WHERE d.reserva_id=r.reserva_id) AS equipos
 FROM renta.Reserva r JOIN renta.Usuario u ON u.usuario_id=r.cliente_id
 WHERE r.negocio_id=@negocio_id AND r.estado IN('Pendiente','Confirmada')
   AND r.fecha_inicio>=GETDATE() AND r.fecha_inicio<DATEADD(DAY,@dias+1,CONVERT(date,GETDATE()))
 ORDER BY r.fecha_inicio,r.reserva_id;
END TRY BEGIN CATCH THROW; END CATCH END
GO
