USE RentaTicaDB;
GO

/* Nombre: usp_Reserva_ListarVencidas
   Descripcion: Lista reservas activas cuya fecha final ya paso
   Parametros: @negocio_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reserva_ListarVencidas @negocio_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT r.reserva_id,r.fecha_fin,r.estado,u.nombre_completo AS cliente
 FROM renta.Reserva r JOIN renta.Usuario u ON u.usuario_id=r.cliente_id
 WHERE r.negocio_id=@negocio_id AND r.estado IN('Pendiente','Confirmada','En curso') AND r.fecha_fin<GETDATE()
 ORDER BY r.fecha_fin;
END TRY BEGIN CATCH THROW; END CATCH END
GO
