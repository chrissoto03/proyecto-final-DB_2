/* Escenario temporal para verificar login JWT y la ruta GET /api/equipos.
   Ejecute en una base local de pruebas. Luego use las credenciales que se muestran.
   Al terminar, ejecute pruebas_api_limpiar.sql.
*/
USE RentaTicaDB;
GO
SET NOCOUNT ON;

DELETE e FROM renta.Equipo e
JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
WHERE n.email_contacto='api@prueba.test';
DELETE c FROM renta.CategoriaEquipo c
JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
WHERE n.email_contacto='api@prueba.test';
DELETE FROM renta.Usuario WHERE email='operador@api.prueba.test';
DELETE FROM renta.Negocio WHERE email_contacto='api@prueba.test';
GO

DECLARE @negocio_id INT,@usuario_id INT,@categoria_id INT,@equipo_id INT;
EXEC renta.usp_Negocio_Crear
  @nombre='Negocio temporal API',@email_contacto='api@prueba.test',
  @negocio_id=@negocio_id OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado
  @nombre_completo='Operador temporal API',@email='operador@api.prueba.test',
  @password=N'RentaTicaAPI2026!',@rol_nombre='Operador',
  @negocio_id=@negocio_id,@usuario_id=@usuario_id OUTPUT;
EXEC renta.usp_CategoriaEquipo_Crear
  @negocio_id=@negocio_id,@nombre='Categoria API',
  @tarifa_hora=10,@tarifa_dia=40,@monto_deposito=0,
  @categoria_id=@categoria_id OUTPUT;
EXEC renta.usp_Equipo_Crear
  @negocio_id=@negocio_id,@categoria_id=@categoria_id,
  @codigo_interno='API-001',@equipo_id=@equipo_id OUTPUT;

SELECT @usuario_id AS usuario_id,@negocio_id AS negocio_id,@equipo_id AS equipo_id,
       'operador@api.prueba.test' AS correo,'RentaTicaAPI2026!' AS contrasena_temporal;
GO