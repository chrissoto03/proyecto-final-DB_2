USE RentaTicaDB;
GO

/* Nombre: usp_Mantenimiento_ListarPorEquipo
   Descripcion: Lista el historial de mantenimiento de un equipo
   Parametros: @negocio_id, @equipo_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Mantenimiento_ListarPorEquipo @negocio_id INT,@equipo_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 IF NOT EXISTS(SELECT 1 FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
               WHERE e.equipo_id=@equipo_id AND c.negocio_id=@negocio_id) THROW 50001,'Equipo no existe en el negocio.',1;
 SELECT m.mantenimiento_id,m.tipo,m.descripcion,m.costo,m.fecha_inicio,m.fecha_fin,u.nombre_completo AS operador
 FROM renta.Mantenimiento m LEFT JOIN renta.Usuario u ON u.usuario_id=m.operador_id
 WHERE m.equipo_id=@equipo_id ORDER BY m.fecha_inicio DESC,m.mantenimiento_id DESC;
END TRY BEGIN CATCH THROW; END CATCH END
GO
