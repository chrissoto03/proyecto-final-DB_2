USE RentaTicaDB;
GO

/* Nombre: usp_Reporte_InventarioPorCategoria
   Descripcion: Resume el inventario y sus estados por categoria
   Parametros: @negocio_id
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reporte_InventarioPorCategoria @negocio_id INT
AS BEGIN SET NOCOUNT ON; BEGIN TRY
 SELECT c.categoria_id,c.nombre,COUNT(e.equipo_id) AS total,
        SUM(CASE WHEN e.estado='Disponible' THEN 1 ELSE 0 END) AS disponibles,
        SUM(CASE WHEN e.estado='Alquilado' THEN 1 ELSE 0 END) AS alquilados,
        SUM(CASE WHEN e.estado='Reservado' THEN 1 ELSE 0 END) AS reservados,
        SUM(CASE WHEN e.estado IN('Mantenimiento','Averiado','Fuera de servicio') THEN 1 ELSE 0 END) AS fuera_operacion
 FROM renta.CategoriaEquipo c LEFT JOIN renta.Equipo e ON e.categoria_id=c.categoria_id
 WHERE c.negocio_id=@negocio_id GROUP BY c.categoria_id,c.nombre ORDER BY c.nombre;
END TRY BEGIN CATCH THROW; END CATCH END
GO
