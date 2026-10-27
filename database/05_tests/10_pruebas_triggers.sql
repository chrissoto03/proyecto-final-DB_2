/* ============================================================================
   Pruebas de 10_triggers.sql
   Requiere todos los scripts 00 a 10. Re-ejecutable; limpia sus datos.
   Ejecutar el archivo completo (Ctrl+A, F5) para conservar las variables.
   ============================================================================ */
USE RentaTicaDB;
GO
SET NOCOUNT ON;
DELETE a FROM renta.AuditoriaEquipo a JOIN renta.Equipo e ON e.equipo_id=a.equipo_id JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg10@prueba.test';
DELETE e FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg10@prueba.test';
DELETE c FROM renta.CategoriaEquipo c JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg10@prueba.test';
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba10.test';
DELETE FROM renta.Negocio WHERE email_contacto='neg10@prueba.test';
GO

DECLARE @neg INT,@oper INT,@cli INT,@cat INT,@eq INT;
EXEC renta.usp_Negocio_Crear @nombre='Negocio Prueba 10',@email_contacto='neg10@prueba.test',@negocio_id=@neg OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo='Operador 10',@email='oper@prueba10.test',@password=N'Clave1234',@rol_nombre='Operador',@negocio_id=@neg,@usuario_id=@oper OUTPUT;
EXEC renta.usp_Usuario_Registrar @nombre_completo='Cliente 10',@email='cli@prueba10.test',@password=N'Clave1234',@usuario_id=@cli OUTPUT;

PRINT '--- Trigger usuario: Cliente no puede tener negocio (esperado: error 50003) ---';
BEGIN TRY
 UPDATE renta.Usuario SET negocio_id=@neg WHERE usuario_id=@cli;
 SELECT 'ERROR: el trigger debio rechazar el cambio' AS resultado;
END TRY
BEGIN CATCH
 SELECT ERROR_NUMBER() AS numero,ERROR_MESSAGE() AS mensaje;
 IF ERROR_NUMBER()<>50003 THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM renta.Usuario WHERE usuario_id=@cli AND negocio_id IS NOT NULL)
 THROW 51000,'El trigger permitio asociar el cliente a un negocio.',1;

EXEC renta.usp_CategoriaEquipo_Crear @negocio_id=@neg,@nombre='Categoria Prueba 10',@tarifa_hora=10,@tarifa_dia=40,@monto_deposito=0,@categoria_id=@cat OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id=@neg,@categoria_id=@cat,@codigo_interno='TRG-10',@equipo_id=@eq OUTPUT;
PRINT '--- Trigger auditoria: dos cambios deben crear dos filas ---';
EXEC renta.usp_Equipo_ActualizarEstado @equipo_id=@eq,@negocio_id=@neg,@nuevo_estado='Averiado',@usuario_id=@oper;
EXEC renta.usp_Equipo_ActualizarEstado @equipo_id=@eq,@negocio_id=@neg,@nuevo_estado='Disponible',@usuario_id=@oper;
SELECT auditoria_id,equipo_id,usuario_id,estado_anterior,estado_nuevo,fecha_hora FROM renta.AuditoriaEquipo WHERE equipo_id=@eq ORDER BY auditoria_id;
IF (SELECT COUNT(*) FROM renta.AuditoriaEquipo WHERE equipo_id=@eq AND usuario_id=@oper)<>2
 THROW 51000,'El trigger no registro ambos cambios de estado.',1;

DELETE FROM renta.AuditoriaEquipo WHERE equipo_id=@eq;
DELETE FROM renta.Equipo WHERE equipo_id=@eq;
DELETE FROM renta.CategoriaEquipo WHERE categoria_id=@cat;
DELETE FROM renta.Usuario WHERE usuario_id IN(@oper,@cli);
DELETE FROM renta.Negocio WHERE negocio_id=@neg;
PRINT 'Pruebas del script 10 finalizadas y base limpia.';
GO
