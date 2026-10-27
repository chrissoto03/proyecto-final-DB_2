USE RentaTicaDB;
GO

/* Cada procedimiento devuelve un result set y aplica el filtro de tenant. */
/* Nombre: usp_Reserva_CantidadPorEstado
   Descripcion: Agrupa las reservas del negocio por estado
   Parametros: @negocio_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reserva_CantidadPorEstado @negocio_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT estado,COUNT(*) AS total FROM renta.Reserva WHERE negocio_id=@negocio_id GROUP BY estado ORDER BY estado;
END TRY BEGIN CATCH THROW; END CATCH END
GO
