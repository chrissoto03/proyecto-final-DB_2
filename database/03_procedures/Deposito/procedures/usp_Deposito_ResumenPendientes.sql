USE RentaTicaDB;
GO

/* Nombre: usp_Deposito_ResumenPendientes
   Descripcion: Resume garantias que siguen en custodia
   Parametros: @negocio_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Deposito_ResumenPendientes @negocio_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT COUNT(*) AS cantidad,SUM(d.monto_cobrado) AS monto_en_custodia
 FROM renta.Deposito d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id
 WHERE r.negocio_id=@negocio_id AND d.fecha_devolucion IS NULL;
END TRY BEGIN CATCH THROW; END CATCH END
GO
