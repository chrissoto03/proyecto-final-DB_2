USE RentaTicaDB;
GO

/* Nombre: usp_Reserva_DisponibilidadPorCategoria
   Descripcion: Cuenta equipos disponibles por categoria para un rango
   Parametros: @negocio_id, @fecha_inicio, @fecha_fin
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reserva_DisponibilidadPorCategoria
 @negocio_id INT,@fecha_inicio DATETIME,@fecha_fin DATETIME
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 IF @fecha_inicio IS NULL OR @fecha_fin<=@fecha_inicio THROW 50003,'Rango de fechas invalido.',1;
 SELECT c.categoria_id,c.nombre,COUNT(*) AS total_equipo,
        SUM(CASE WHEN renta.fn_EquipoEstaDisponible(e.equipo_id,@fecha_inicio,@fecha_fin)=1 THEN 1 ELSE 0 END) AS disponibles
 FROM renta.CategoriaEquipo c JOIN renta.Equipo e ON e.categoria_id=c.categoria_id
 WHERE c.negocio_id=@negocio_id GROUP BY c.categoria_id,c.nombre ORDER BY c.nombre;
END TRY BEGIN CATCH THROW; END CATCH END
GO
