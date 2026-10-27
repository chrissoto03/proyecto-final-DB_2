/* ============================================================================
   Pruebas del script 08_sp_transaccionales.sql
   Ejecutar despues de cargar los scripts 00 a 08.
   Re-ejecutable: elimina solo los datos del negocio de prueba 08.
   ============================================================================ */
USE RentaTicaDB;
GO

DELETE p FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id
 JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg08@prueba.test';
DELETE d FROM renta.Deposito d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id
 JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg08@prueba.test';
DELETE dr FROM renta.DetalleReserva dr JOIN renta.Reserva r ON r.reserva_id=dr.reserva_id
 JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg08@prueba.test';
DELETE r FROM renta.Reserva r JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg08@prueba.test';
DELETE a FROM renta.AuditoriaEquipo a JOIN renta.Equipo e ON e.equipo_id=a.equipo_id
 JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
 WHERE n.email_contacto='neg08@prueba.test';
DELETE m FROM renta.Mantenimiento m JOIN renta.Equipo e ON e.equipo_id=m.equipo_id
 JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
 WHERE n.email_contacto='neg08@prueba.test';
DELETE e FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
 JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg08@prueba.test';
DELETE c FROM renta.CategoriaEquipo c JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
 WHERE n.email_contacto='neg08@prueba.test';
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba08.test';
DELETE FROM renta.Negocio WHERE email_contacto='neg08@prueba.test';
GO

DECLARE @negocio_id INT,@operador_id INT,@cliente_id INT,@categoria_id INT,@equipo_id INT;
DECLARE @reserva_id INT,@pago_id INT,@detalle_id INT;
DECLARE @fecha_inicio DATETIME=DATEADD(MINUTE,-1,GETDATE());
DECLARE @fecha_fin DATETIME=DATEADD(MINUTE,118,@fecha_inicio);
DECLARE @equipos_json NVARCHAR(MAX);
DECLARE @equipos_duplicados NVARCHAR(MAX);
DECLARE @metodo_pago_id INT=(SELECT metodo_pago_id FROM renta.MetodoPago WHERE nombre='Efectivo');

EXEC renta.usp_Negocio_Crear @nombre='Negocio prueba 08',@email_contacto='neg08@prueba.test',@negocio_id=@negocio_id OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo='Operador 08',@email='oper@prueba08.test',
 @password=N'Clave1234',@rol_nombre='Operador',@negocio_id=@negocio_id,@usuario_id=@operador_id OUTPUT;
EXEC renta.usp_Usuario_Registrar @nombre_completo='Cliente 08',@email='cli@prueba08.test',
 @password=N'Clave1234',@usuario_id=@cliente_id OUTPUT;
EXEC renta.usp_CategoriaEquipo_Crear @negocio_id=@negocio_id,@nombre='Bicicleta 08',
 @tarifa_hora=10,@tarifa_dia=20,@monto_deposito=0,@categoria_id=@categoria_id OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id=@negocio_id,@categoria_id=@categoria_id,
 @codigo_interno='BIKE-08',@equipo_id=@equipo_id OUTPUT;

PRINT '--- Crear Walk-in con un equipo (esperado: reserva En curso y monto 20) ---';
SET @equipos_json=N'[' + CONVERT(NVARCHAR(12),@equipo_id) + N']';
SET @equipos_duplicados=N'[' + CONVERT(NVARCHAR(12),@equipo_id) + N',' + CONVERT(NVARCHAR(12),@equipo_id) + N']';
EXEC renta.usp_Reserva_Crear @negocio_id=@negocio_id,@cliente_id=@cliente_id,@operador_id=@operador_id,
 @tipo_reserva='Walk-in',@fecha_inicio=@fecha_inicio,@fecha_fin=@fecha_fin,
 @equipos_json=@equipos_json,@reserva_id=@reserva_id OUTPUT;
SELECT r.reserva_id,r.estado,r.monto_final,e.estado AS estado_equipo
FROM renta.Reserva r JOIN renta.DetalleReserva d ON d.reserva_id=r.reserva_id
JOIN renta.Equipo e ON e.equipo_id=d.equipo_id WHERE r.reserva_id=@reserva_id;
IF NOT EXISTS(SELECT 1 FROM renta.Reserva WHERE reserva_id=@reserva_id AND estado='En curso' AND monto_final=20)
   THROW 51000,'Fallo la creacion atomica de la reserva Walk-in.',1;

PRINT '--- Equipo duplicado: debe fallar con 50003 y no crear una segunda reserva ---';
BEGIN TRY
 EXEC renta.usp_Reserva_Crear @negocio_id=@negocio_id,@cliente_id=@cliente_id,@operador_id=@operador_id,
  @tipo_reserva='Walk-in',@fecha_inicio=@fecha_inicio,@fecha_fin=@fecha_fin,
  @equipos_json=@equipos_duplicados,
  @reserva_id=@reserva_id OUTPUT;
END TRY BEGIN CATCH SELECT ERROR_NUMBER() AS numero,ERROR_MESSAGE() AS mensaje; END CATCH
SELECT COUNT(*) AS reservas_creadas FROM renta.Reserva WHERE negocio_id=@negocio_id;
IF (SELECT COUNT(*) FROM renta.Reserva WHERE negocio_id=@negocio_id)<>1
   THROW 51000,'La lista duplicada genero una reserva parcial.',1;

PRINT '--- Pago completo (esperado: un pago por 20, una sola vez) ---';
EXEC renta.usp_Pago_Registrar @reserva_id=@reserva_id,@negocio_id=@negocio_id,
 @metodo_pago_id=@metodo_pago_id,@monto=20,@pago_id=@pago_id OUTPUT;
EXEC renta.usp_Pago_ListarPorReserva @reserva_id=@reserva_id,@negocio_id=@negocio_id;
IF (SELECT COUNT(*) FROM renta.Pago WHERE reserva_id=@reserva_id AND estado='Completado')<>1
   THROW 51000,'No se registro exactamente un pago.',1;

PRINT '--- Devolucion del equipo (esperado: reserva Completada, equipo Disponible) ---';
SELECT @detalle_id=detalle_id FROM renta.DetalleReserva WHERE reserva_id=@reserva_id;
EXEC renta.usp_Equipo_Devolver @detalle_id=@detalle_id,@negocio_id=@negocio_id,
 @estado_devolucion='Bueno',@usuario_id=@operador_id;
SELECT r.estado AS estado_reserva,e.estado AS estado_equipo,d.fecha_hora_devolucion,d.estado_equipo_devolucion
FROM renta.Reserva r JOIN renta.DetalleReserva d ON d.reserva_id=r.reserva_id
JOIN renta.Equipo e ON e.equipo_id=d.equipo_id WHERE r.reserva_id=@reserva_id;
IF NOT EXISTS(SELECT 1 FROM renta.Reserva r JOIN renta.DetalleReserva d ON d.reserva_id=r.reserva_id
              JOIN renta.Equipo e ON e.equipo_id=d.equipo_id
              WHERE r.reserva_id=@reserva_id AND r.estado='Completada'
                AND d.fecha_hora_devolucion IS NOT NULL AND e.estado='Disponible')
   THROW 51000,'Fallo la devolucion atomica del equipo.',1;

/* Limpieza final del escenario de demostracion. */
DELETE p FROM renta.Pago p WHERE p.reserva_id=@reserva_id;
DELETE d FROM renta.Deposito d WHERE d.reserva_id=@reserva_id;
DELETE FROM renta.DetalleReserva WHERE reserva_id=@reserva_id;
DELETE FROM renta.Reserva WHERE reserva_id=@reserva_id;
DELETE a FROM renta.AuditoriaEquipo a WHERE a.equipo_id=@equipo_id;
DELETE FROM renta.Equipo WHERE equipo_id=@equipo_id;
DELETE FROM renta.CategoriaEquipo WHERE categoria_id=@categoria_id;
DELETE FROM renta.Usuario WHERE usuario_id IN(@operador_id,@cliente_id);
DELETE FROM renta.Negocio WHERE negocio_id=@negocio_id;
GO
