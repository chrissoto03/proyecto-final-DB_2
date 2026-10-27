USE RentaTicaDB;
GO

/* Nombre: usp_AuditoriaEquipo_ListarPorUsuario
   Descripcion: Lista cambios de equipo atribuibles a un usuario
   Parametros: @negocio_id, @usuario_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_AuditoriaEquipo_ListarPorUsuario
 @negocio_id INT,@usuario_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT a.auditoria_id,a.equipo_id,e.codigo_interno,a.estado_anterior,a.estado_nuevo,a.fecha_hora
 FROM renta.AuditoriaEquipo a JOIN renta.Equipo e ON e.equipo_id=a.equipo_id
 JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
 WHERE c.negocio_id=@negocio_id AND a.usuario_id=@usuario_id
 ORDER BY a.fecha_hora DESC,a.auditoria_id DESC;
END TRY BEGIN CATCH THROW; END CATCH END
GO
