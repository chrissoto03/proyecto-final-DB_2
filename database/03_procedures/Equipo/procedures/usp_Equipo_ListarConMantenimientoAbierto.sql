USE RentaTicaDB;
GO

/* Nombre: usp_Equipo_ListarConMantenimientoAbierto
   Descripcion: Lista equipos con una orden de mantenimiento abierta
   Parametros: @negocio_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Equipo_ListarConMantenimientoAbierto @negocio_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT e.equipo_id,e.codigo_interno,c.nombre AS categoria,m.mantenimiento_id,m.tipo,m.fecha_inicio,m.costo
 FROM renta.Mantenimiento m JOIN renta.Equipo e ON e.equipo_id=m.equipo_id
 JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
 WHERE c.negocio_id=@negocio_id AND m.fecha_fin IS NULL ORDER BY m.fecha_inicio,e.codigo_interno;
END TRY BEGIN CATCH THROW; END CATCH END
GO
