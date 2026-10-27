USE RentaTicaDB;
GO

/* Nombre: usp_Pago_ListarPorCliente
   Descripcion: Lista pagos de un cliente dentro del negocio
   Parametros: @negocio_id, @cliente_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Pago_ListarPorCliente @negocio_id INT,@cliente_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT p.pago_id,p.reserva_id,p.monto,p.estado,p.fecha_pago,m.nombre AS metodo_pago
 FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id
 JOIN renta.MetodoPago m ON m.metodo_pago_id=p.metodo_pago_id
 WHERE r.negocio_id=@negocio_id AND r.cliente_id=@cliente_id ORDER BY p.fecha_pago DESC,p.pago_id DESC;
END TRY BEGIN CATCH THROW; END CATCH END
GO
