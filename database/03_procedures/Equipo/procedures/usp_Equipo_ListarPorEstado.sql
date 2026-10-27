USE RentaTicaDB;
GO

/* Nombre: usp_Equipo_ListarPorEstado
   Descripcion: Lista el inventario del negocio filtrado por estado
   Parametros: @negocio_id, @estado
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Equipo_ListarPorEstado @negocio_id INT,@estado VARCHAR(20)
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 IF @estado NOT IN('Disponible','Reservado','Alquilado','Mantenimiento','Averiado','Fuera de servicio')
   THROW 50003,'Estado de equipo invalido.',1;
 SELECT e.equipo_id,e.codigo_interno,e.descripcion,e.estado,c.categoria_id,c.nombre AS categoria
 FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
 WHERE c.negocio_id=@negocio_id AND e.estado=@estado ORDER BY c.nombre,e.codigo_interno;
END TRY BEGIN CATCH THROW; END CATCH END
GO
