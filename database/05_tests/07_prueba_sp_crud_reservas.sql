/* ============================================================================
   Pruebas del script 07_sp_crud_reservas.sql
   ============================================================================
   Ejecutar despues de instalar los scripts 00 a 10.
   Las reservas, pagos y depositos se insertan directamente porque su creacion
   real (transacciones) esta en el script 08; aqui solo se prueban las
   consultas y el Eliminar. Re-ejecutable: limpia al inicio y al final.
   ============================================================================ */

USE RentaTicaDB;
GO

/* ---------- Limpieza previa ---------- */
DELETE p FROM renta.Pago p INNER JOIN renta.Reserva r ON r.reserva_id = p.reserva_id
 INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
 WHERE n.email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
DELETE d FROM renta.Deposito d INNER JOIN renta.Reserva r ON r.reserva_id = d.reserva_id
 INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
 WHERE n.email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
DELETE d FROM renta.DetalleReserva d INNER JOIN renta.Reserva r ON r.reserva_id = d.reserva_id
 INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
 WHERE n.email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
DELETE r FROM renta.Reserva r INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
 WHERE n.email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
DELETE a FROM renta.AuditoriaEquipo a INNER JOIN renta.Equipo e ON e.equipo_id = a.equipo_id
 INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
 INNER JOIN renta.Negocio n ON n.negocio_id = c.negocio_id
 WHERE n.email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
DELETE e FROM renta.Equipo e INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
 INNER JOIN renta.Negocio n ON n.negocio_id = c.negocio_id
 WHERE n.email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
DELETE c FROM renta.CategoriaEquipo c INNER JOIN renta.Negocio n ON n.negocio_id = c.negocio_id
 WHERE n.email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba07.test';
DELETE FROM renta.Negocio WHERE email_contacto IN ('neg07a@prueba.test', 'neg07b@prueba.test');
GO

DECLARE @negA INT, @negB INT, @oper INT, @c1 INT, @c2 INT, @cat INT, @e1 INT, @e2 INT;
DECLARE @r1 INT, @r2 INT, @r3 INT, @r4 INT, @det1 INT, @pago1 INT, @x INT;
DECLARE @mEfectivo INT = (SELECT metodo_pago_id FROM renta.MetodoPago WHERE nombre = 'Efectivo');
DECLARE @mTarjeta  INT = (SELECT metodo_pago_id FROM renta.MetodoPago WHERE nombre = 'Tarjeta');
DECLARE @mSinpe    INT = (SELECT metodo_pago_id FROM renta.MetodoPago WHERE nombre = 'SINPE Movil');

/* ---------- Preparacion con los SPs ---------- */
EXEC renta.usp_Negocio_Crear @nombre = 'Negocio A 07', @email_contacto = 'neg07a@prueba.test', @negocio_id = @negA OUTPUT;
EXEC renta.usp_Negocio_Crear @nombre = 'Negocio B 07', @email_contacto = 'neg07b@prueba.test', @negocio_id = @negB OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo = 'Operador 07', @email = 'oper@prueba07.test',
     @password = N'Clave1234', @rol_nombre = 'Operador', @negocio_id = @negA, @usuario_id = @oper OUTPUT;
EXEC renta.usp_Usuario_Registrar @nombre_completo = 'Cliente Uno', @email = 'c1@prueba07.test',
     @password = N'Clave1234', @usuario_id = @c1 OUTPUT;
EXEC renta.usp_Usuario_Registrar @nombre_completo = 'Cliente Dos', @email = 'c2@prueba07.test',
     @password = N'Clave1234', @usuario_id = @c2 OUTPUT;
EXEC renta.usp_CategoriaEquipo_Crear @negocio_id = @negA, @nombre = 'Tabla de Surf',
     @tarifa_hora = 15, @tarifa_dia = 50, @monto_deposito = 100, @categoria_id = @cat OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id = @negA, @categoria_id = @cat, @codigo_interno = 'SURF-001', @equipo_id = @e1 OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id = @negA, @categoria_id = @cat, @codigo_interno = 'SURF-002', @equipo_id = @e2 OUTPUT;

/* ---------- Datos de prueba insertados directamente ---------- */
-- R1: confirmada, 60 de monto, pagado 50 (30 efectivo + 20 tarjeta), deposito de 100 pendiente
INSERT INTO renta.Reserva (negocio_id, cliente_id, operador_id, tipo_reserva, estado, fecha_inicio, fecha_fin, monto_final)
VALUES (@negA, @c1, @oper, 'Anticipada', 'Confirmada', '2026-12-10 09:00', '2026-12-10 13:00', 60);
SET @r1 = SCOPE_IDENTITY();
INSERT INTO renta.DetalleReserva (reserva_id, equipo_id, tarifa_aplicada) VALUES (@r1, @e1, 60);
SET @det1 = SCOPE_IDENTITY();
INSERT INTO renta.Pago (reserva_id, metodo_pago_id, monto) VALUES (@r1, @mEfectivo, 30);
SET @pago1 = SCOPE_IDENTITY();
INSERT INTO renta.Pago (reserva_id, metodo_pago_id, monto) VALUES (@r1, @mTarjeta, 20);
INSERT INTO renta.Deposito (reserva_id, monto_cobrado) VALUES (@r1, 100);

-- R2: cancelada, sin pagos ni deposito (se podra eliminar)
INSERT INTO renta.Reserva (negocio_id, cliente_id, tipo_reserva, estado, fecha_inicio, fecha_fin, monto_final)
VALUES (@negA, @c2, 'Walk-in', 'Cancelada', '2026-12-11 09:00', '2026-12-11 11:00', 30);
SET @r2 = SCOPE_IDENTITY();
INSERT INTO renta.DetalleReserva (reserva_id, equipo_id, tarifa_aplicada) VALUES (@r2, @e2, 30);

-- R3: completada, pagada 50 por SINPE, deposito liquidado (80 devuelto + 20 retenido)
INSERT INTO renta.Reserva (negocio_id, cliente_id, operador_id, tipo_reserva, estado, fecha_inicio, fecha_fin, monto_final)
VALUES (@negA, @c1, @oper, 'Anticipada', 'Completada', '2026-12-05 09:00', '2026-12-05 17:00', 50);
SET @r3 = SCOPE_IDENTITY();
INSERT INTO renta.DetalleReserva (reserva_id, equipo_id, tarifa_aplicada, estado_equipo_devolucion) VALUES (@r3, @e2, 50, 'Averiado');
INSERT INTO renta.Pago (reserva_id, metodo_pago_id, monto) VALUES (@r3, @mSinpe, 50);
INSERT INTO renta.Deposito (reserva_id, monto_cobrado, monto_devuelto, monto_retencion, fecha_devolucion)
VALUES (@r3, 100, 80, 20, '2026-12-05 17:30');

-- R4: cancelada pero con un pago reembolsado (debe conservarse)
INSERT INTO renta.Reserva (negocio_id, cliente_id, tipo_reserva, estado, fecha_inicio, fecha_fin, monto_final)
VALUES (@negA, @c1, 'Walk-in', 'Cancelada', '2026-12-12 09:00', '2026-12-12 10:00', 15);
SET @r4 = SCOPE_IDENTITY();
INSERT INTO renta.Pago (reserva_id, metodo_pago_id, monto, estado) VALUES (@r4, @mTarjeta, 15, 'Reembolsado');

-- Dos filas de auditoria para SURF-001
INSERT INTO renta.AuditoriaEquipo (equipo_id, usuario_id, estado_anterior, estado_nuevo, fecha_hora)
VALUES (@e1, @oper, 'Disponible', 'Mantenimiento', '2026-11-01 10:00'),
       (@e1, @oper, 'Mantenimiento', 'Disponible', '2026-11-02 10:00');

/* ============================ RESERVA ============================ */
PRINT '--- Reserva_ObtenerPorId R1: 4 result sets (esperado: total_pagado 50, saldo 10, 1 equipo, 2 pagos, deposito 100) ---';
EXEC renta.usp_Reserva_ObtenerPorId @reserva_id = @r1, @negocio_id = @negA;

PRINT '--- AISLAMIENTO, ERROR esperado 50001: el negocio B no ve la reserva del A ---';
BEGIN TRY
    EXEC renta.usp_Reserva_ObtenerPorId @reserva_id = @r1, @negocio_id = @negB;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Reserva_Listar: todas (esperado: 4) ---';
EXEC renta.usp_Reserva_Listar @negocio_id = @negA;
PRINT '--- Reserva_Listar: solo Canceladas (esperado: 2) ---';
EXEC renta.usp_Reserva_Listar @negocio_id = @negA, @estado = 'Cancelada';
PRINT '--- Reserva_Listar: cliente Uno (esperado: 3) ---';
EXEC renta.usp_Reserva_Listar @negocio_id = @negA, @cliente_id = @c1;
PRINT '--- Reserva_Listar: inicio entre 10 y 11 de diciembre (esperado: 1, la R1) ---';
EXEC renta.usp_Reserva_Listar @negocio_id = @negA, @desde = '2026-12-10', @hasta = '2026-12-11';
PRINT '--- Reserva_Listar: negocio B (esperado: 0 filas) ---';
EXEC renta.usp_Reserva_Listar @negocio_id = @negB;

PRINT '--- ERROR esperado 50003: estado invalido ---';
BEGIN TRY
    EXEC renta.usp_Reserva_Listar @negocio_id = @negA, @estado = 'Inventado';
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Reserva_ListarPorCliente: Cliente Uno (esperado: 3 reservas) ---';
EXEC renta.usp_Reserva_ListarPorCliente @cliente_id = @c1;

PRINT '--- ERROR esperado 50001: cliente inexistente ---';
BEGIN TRY
    EXEC renta.usp_Reserva_ListarPorCliente @cliente_id = 999999;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

/* ======================== DETALLE RESERVA ======================== */
PRINT '--- DetalleReserva_ListarPorReserva R1 (esperado: 1 fila, SURF-001) ---';
EXEC renta.usp_DetalleReserva_ListarPorReserva @reserva_id = @r1, @negocio_id = @negA;
PRINT '--- DetalleReserva_ObtenerPorId (esperado: 1 fila) ---';
EXEC renta.usp_DetalleReserva_ObtenerPorId @detalle_id = @det1, @negocio_id = @negA;

PRINT '--- ERROR esperado 50001: detalle de otro negocio ---';
BEGIN TRY
    EXEC renta.usp_DetalleReserva_ObtenerPorId @detalle_id = @det1, @negocio_id = @negB;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

/* ============================== PAGO ============================== */
PRINT '--- Pago_ObtenerPorId (esperado: 30, Efectivo) ---';
EXEC renta.usp_Pago_ObtenerPorId @pago_id = @pago1, @negocio_id = @negA;
PRINT '--- Pago_ListarPorReserva R1 (esperado: 2 pagos) ---';
EXEC renta.usp_Pago_ListarPorReserva @reserva_id = @r1, @negocio_id = @negA;
PRINT '--- Pago_Listar: todos (esperado: 4) ---';
EXEC renta.usp_Pago_Listar @negocio_id = @negA;
PRINT '--- Pago_Listar: solo Efectivo (esperado: 1) ---';
EXEC renta.usp_Pago_Listar @negocio_id = @negA, @metodo_pago_id = @mEfectivo;
PRINT '--- Pago_Listar: solo Reembolsado (esperado: 1) ---';
EXEC renta.usp_Pago_Listar @negocio_id = @negA, @estado = 'Reembolsado';

PRINT '--- ERROR esperado 50003: estado de pago invalido ---';
BEGIN TRY
    EXEC renta.usp_Pago_Listar @negocio_id = @negA, @estado = 'Pagado';
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

/* ============================ DEPOSITO ============================ */
PRINT '--- Deposito de R1 (esperado: Pendiente de liquidar) ---';
EXEC renta.usp_Deposito_ObtenerPorReserva @reserva_id = @r1, @negocio_id = @negA;
PRINT '--- Deposito de R3 (esperado: Liquidado, devuelto 80, retenido 20) ---';
EXEC renta.usp_Deposito_ObtenerPorReserva @reserva_id = @r3, @negocio_id = @negA;
PRINT '--- Deposito_Listar: todos (esperado: 2) y solo pendientes (esperado: 1) ---';
EXEC renta.usp_Deposito_Listar @negocio_id = @negA;
EXEC renta.usp_Deposito_Listar @negocio_id = @negA, @solo_pendientes = 1;

PRINT '--- ERROR esperado 50001: reserva sin deposito (R2) ---';
BEGIN TRY
    EXEC renta.usp_Deposito_ObtenerPorReserva @reserva_id = @r2, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

/* ========================== AUDITORIA ========================== */
PRINT '--- AuditoriaEquipo_ListarPorEquipo SURF-001 (esperado: 2 filas, la mas reciente primero) ---';
EXEC renta.usp_AuditoriaEquipo_ListarPorEquipo @equipo_id = @e1, @negocio_id = @negA;
PRINT '--- AuditoriaEquipo_Listar del negocio (esperado: 2 filas) ---';
EXEC renta.usp_AuditoriaEquipo_Listar @negocio_id = @negA;
PRINT '--- AuditoriaEquipo_Listar solo 1 de noviembre (esperado: 1 fila) ---';
EXEC renta.usp_AuditoriaEquipo_Listar @negocio_id = @negA, @desde = '2026-11-01', @hasta = '2026-11-02';

/* ============================ ELIMINAR ============================ */
PRINT '--- ERROR esperado 50004: eliminar reserva Confirmada (R1) ---';
BEGIN TRY
    EXEC renta.usp_Reserva_Eliminar @reserva_id = @r1, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50004: eliminar reserva Completada (R3) ---';
BEGIN TRY
    EXEC renta.usp_Reserva_Eliminar @reserva_id = @r3, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50002: eliminar reserva Cancelada con pago (R4) ---';
BEGIN TRY
    EXEC renta.usp_Reserva_Eliminar @reserva_id = @r4, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Eliminar reserva Cancelada sin pagos (R2): esperado sin error, y luego 50001 al consultarla ---';
EXEC renta.usp_Reserva_Eliminar @reserva_id = @r2, @negocio_id = @negA;
BEGIN TRY
    EXEC renta.usp_Reserva_ObtenerPorId @reserva_id = @r2, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

SELECT COUNT(*) AS detalles_de_r2_restantes FROM renta.DetalleReserva WHERE reserva_id = @r2;   -- esperado 0

/* ---------- Limpieza final ---------- */
DELETE FROM renta.Pago WHERE reserva_id IN (@r1, @r3, @r4);
DELETE FROM renta.Deposito WHERE reserva_id IN (@r1, @r3);
DELETE FROM renta.DetalleReserva WHERE reserva_id IN (@r1, @r3);
DELETE FROM renta.Reserva WHERE reserva_id IN (@r1, @r3, @r4);
DELETE FROM renta.AuditoriaEquipo WHERE equipo_id IN (@e1, @e2);
DELETE FROM renta.Equipo WHERE equipo_id IN (@e1, @e2);
DELETE FROM renta.CategoriaEquipo WHERE categoria_id = @cat;
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba07.test';
DELETE FROM renta.Negocio WHERE negocio_id IN (@negA, @negB);
PRINT 'Pruebas del script 07 finalizadas y base limpia.';
GO
