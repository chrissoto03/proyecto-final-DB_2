/* ============================================================================
   Pruebas de 09_sp_consultas_reportes.sql
   Requiere todos los scripts 00 a 10. Re-ejecutable; limpia sus datos.
   Ejecutar el archivo completo (Ctrl+A, F5) para conservar las variables.
   ============================================================================ */
USE RentaTicaDB;
GO
SET NOCOUNT ON;

/* Limpieza previa para permitir re-ejecucion. */
DELETE p FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE d FROM renta.Deposito d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE dr FROM renta.DetalleReserva dr JOIN renta.Reserva r ON r.reserva_id=dr.reserva_id JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE r FROM renta.Reserva r JOIN renta.Negocio n ON n.negocio_id=r.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE a FROM renta.AuditoriaEquipo a JOIN renta.Equipo e ON e.equipo_id=a.equipo_id JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE m FROM renta.Mantenimiento m JOIN renta.Equipo e ON e.equipo_id=m.equipo_id JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE e FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE c FROM renta.CategoriaEquipo c JOIN renta.Negocio n ON n.negocio_id=c.negocio_id WHERE n.email_contacto='neg09@prueba.test';
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba09.test';
DELETE FROM renta.Negocio WHERE email_contacto='neg09@prueba.test';
GO

DECLARE @neg INT,@oper INT,@cli INT,@cat INT,@eq1 INT,@eq2 INT;
DECLARE @rProx INT,@rVencida INT,@rComp INT;
DECLARE @metodo INT=(SELECT TOP(1) metodo_pago_id FROM renta.MetodoPago ORDER BY metodo_pago_id);
DECLARE @hoy DATE=CONVERT(date,GETDATE());
DECLARE @manana DATE=DATEADD(DAY,1,CONVERT(date,GETDATE()));
DECLARE @prox DATETIME=DATEADD(DAY,2,CONVERT(DATETIME,CONVERT(date,GETDATE())));
DECLARE @desde DATETIME=DATEADD(DAY,1,CONVERT(DATETIME,CONVERT(date,GETDATE())));
DECLARE @hasta DATETIME=DATEADD(DAY,4,CONVERT(DATETIME,CONVERT(date,GETDATE())));

EXEC renta.usp_Negocio_Crear @nombre='Negocio Prueba 09',@email_contacto='neg09@prueba.test',@negocio_id=@neg OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo='Operador 09',@email='oper@prueba09.test',@password=N'Clave1234',@rol_nombre='Operador',@negocio_id=@neg,@usuario_id=@oper OUTPUT;
EXEC renta.usp_Usuario_Registrar @nombre_completo='Cliente 09',@email='cli@prueba09.test',@password=N'Clave1234',@usuario_id=@cli OUTPUT;
EXEC renta.usp_CategoriaEquipo_Crear @negocio_id=@neg,@nombre='Equipo Reporte 09',@tarifa_hora=10,@tarifa_dia=40,@monto_deposito=25,@categoria_id=@cat OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id=@neg,@categoria_id=@cat,@codigo_interno='REP-09-A',@equipo_id=@eq1 OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id=@neg,@categoria_id=@cat,@codigo_interno='REP-09-B',@equipo_id=@eq2 OUTPUT;

/* Casos para reservas proximas, vencidas y completadas, con pagos y deposito. */
INSERT renta.Reserva(negocio_id,cliente_id,operador_id,tipo_reserva,estado,fecha_inicio,fecha_fin,monto_final) VALUES(@neg,@cli,@oper,'Anticipada','Confirmada',@prox,DATEADD(HOUR,2,@prox),20);
SET @rProx=SCOPE_IDENTITY();
INSERT renta.Reserva(negocio_id,cliente_id,operador_id,tipo_reserva,estado,fecha_inicio,fecha_fin,monto_final) VALUES(@neg,@cli,@oper,'Anticipada','Confirmada',DATEADD(HOUR,-3,GETDATE()),DATEADD(HOUR,-1,GETDATE()),20);
SET @rVencida=SCOPE_IDENTITY();
INSERT renta.Reserva(negocio_id,cliente_id,operador_id,tipo_reserva,estado,fecha_inicio,fecha_fin,monto_final) VALUES(@neg,@cli,@oper,'Walk-in','Completada',DATEADD(DAY,-1,GETDATE()),DATEADD(HOUR,-22,GETDATE()),20);
SET @rComp=SCOPE_IDENTITY();
INSERT renta.DetalleReserva(reserva_id,equipo_id,tarifa_aplicada) VALUES(@rProx,@eq1,20),(@rVencida,@eq2,20),(@rComp,@eq2,20);
INSERT renta.Pago(reserva_id,metodo_pago_id,monto,fecha_pago) VALUES(@rProx,@metodo,20,GETDATE()),(@rComp,@metodo,20,GETDATE());
INSERT renta.Deposito(reserva_id,monto_cobrado) VALUES(@rProx,25);
INSERT renta.Mantenimiento(equipo_id,operador_id,tipo,descripcion,costo,fecha_inicio) VALUES(@eq1,@oper,'Preventivo','Orden abierta 09',5,@hoy),(@eq2,@oper,'Correctivo','Orden cerrada 09',15,DATEADD(DAY,-1,@hoy));
UPDATE renta.Mantenimiento SET fecha_fin=DATEADD(DAY,-1,@hoy) WHERE equipo_id=@eq2 AND descripcion='Orden cerrada 09';
INSERT renta.AuditoriaEquipo(equipo_id,usuario_id,estado_anterior,estado_nuevo) VALUES(@eq1,@oper,'Averiado','Disponible');

PRINT '--- 09.1 Conteo de reservas por estado ---'; EXEC renta.usp_Reserva_CantidadPorEstado @negocio_id=@neg;
PRINT '--- 09.2 Reservas proximas (esperado: 1) ---'; EXEC renta.usp_Reserva_Proximas @negocio_id=@neg,@dias=7;
PRINT '--- 09.3 Reservas vencidas (esperado: 1) ---'; EXEC renta.usp_Reserva_ListarVencidas @negocio_id=@neg;
PRINT '--- 09.4 Disponibilidad por categoria ---'; EXEC renta.usp_Reserva_DisponibilidadPorCategoria @negocio_id=@neg,@fecha_inicio=@desde,@fecha_fin=@hasta;
PRINT '--- 09.5 Inventario disponible ---'; EXEC renta.usp_Equipo_ListarPorEstado @negocio_id=@neg,@estado='Disponible';
PRINT '--- 09.6 Historial de mantenimiento ---'; EXEC renta.usp_Mantenimiento_ListarPorEquipo @negocio_id=@neg,@equipo_id=@eq1;
PRINT '--- 09.7 Pagos por metodo ---'; EXEC renta.usp_Pago_ResumenPorMetodo @negocio_id=@neg,@desde=@hoy,@hasta=@manana;
PRINT '--- 09.8 Pagos del cliente ---'; EXEC renta.usp_Pago_ListarPorCliente @negocio_id=@neg,@cliente_id=@cli;
PRINT '--- 09.9 Depositos pendientes (esperado: 1 y 25) ---'; EXEC renta.usp_Deposito_ResumenPendientes @negocio_id=@neg;
PRINT '--- 09.10 Ingresos por dia ---'; EXEC renta.usp_Reporte_IngresosPorDia @negocio_id=@neg,@desde=@hoy,@hasta=@hoy;
PRINT '--- 09.11 Ocupacion por equipo ---'; EXEC renta.usp_Reporte_OcupacionEquipo @negocio_id=@neg,@desde=@desde,@hasta=@hasta;
PRINT '--- 09.12 Inventario por categoria ---'; EXEC renta.usp_Reporte_InventarioPorCategoria @negocio_id=@neg;
PRINT '--- 09.13 Clientes frecuentes ---'; EXEC renta.usp_Reporte_ClientesFrecuentes @negocio_id=@neg;
PRINT '--- 09.14 Costos de mantenimiento ---'; EXEC renta.usp_Reporte_MantenimientoCostos @negocio_id=@neg;
PRINT '--- 09.15 Auditoria por usuario ---'; EXEC renta.usp_AuditoriaEquipo_ListarPorUsuario @negocio_id=@neg,@usuario_id=@oper;
PRINT '--- 09.16 Equipos con mantenimiento abierto (esperado: REP-09-A) ---'; EXEC renta.usp_Equipo_ListarConMantenimientoAbierto @negocio_id=@neg;

DELETE FROM renta.AuditoriaEquipo WHERE equipo_id IN(@eq1,@eq2);
DELETE FROM renta.Mantenimiento WHERE equipo_id IN(@eq1,@eq2);
DELETE FROM renta.Pago WHERE reserva_id IN(@rProx,@rVencida,@rComp);
DELETE FROM renta.Deposito WHERE reserva_id IN(@rProx,@rVencida,@rComp);
DELETE FROM renta.DetalleReserva WHERE reserva_id IN(@rProx,@rVencida,@rComp);
DELETE FROM renta.Reserva WHERE reserva_id IN(@rProx,@rVencida,@rComp);
DELETE FROM renta.Equipo WHERE equipo_id IN(@eq1,@eq2);
DELETE FROM renta.CategoriaEquipo WHERE categoria_id=@cat;
DELETE FROM renta.Usuario WHERE usuario_id IN(@oper,@cli);
DELETE FROM renta.Negocio WHERE negocio_id=@neg;
PRINT 'Pruebas del script 09 finalizadas y base limpia.';
GO
