/* ============================================================================
   Pruebas del script 06_sp_crud_equipos.sql
   ============================================================================
   Ejecutar despues de instalar los scripts 00 a 10.
   Re-ejecutable: limpia sus propios datos al inicio y al final.
   Los bloques "ERROR esperado" deben mostrar el numero y mensaje indicados.
   ============================================================================ */

USE RentaTicaDB;
GO

/* ---------- Limpieza previa (orden: de hijos a padres) ---------- */
DELETE a FROM renta.AuditoriaEquipo a
 INNER JOIN renta.Equipo e ON e.equipo_id = a.equipo_id
 INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
 INNER JOIN renta.Negocio n ON n.negocio_id = c.negocio_id
 WHERE n.email_contacto IN ('neg06a@prueba.test', 'neg06b@prueba.test');
DELETE m FROM renta.Mantenimiento m
 INNER JOIN renta.Equipo e ON e.equipo_id = m.equipo_id
 INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
 INNER JOIN renta.Negocio n ON n.negocio_id = c.negocio_id
 WHERE n.email_contacto IN ('neg06a@prueba.test', 'neg06b@prueba.test');
DELETE d FROM renta.DetalleReserva d
 INNER JOIN renta.Reserva r ON r.reserva_id = d.reserva_id
 INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
 WHERE n.email_contacto IN ('neg06a@prueba.test', 'neg06b@prueba.test');
DELETE r FROM renta.Reserva r
 INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
 WHERE n.email_contacto IN ('neg06a@prueba.test', 'neg06b@prueba.test');
DELETE e FROM renta.Equipo e
 INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
 INNER JOIN renta.Negocio n ON n.negocio_id = c.negocio_id
 WHERE n.email_contacto IN ('neg06a@prueba.test', 'neg06b@prueba.test');
DELETE c FROM renta.CategoriaEquipo c
 INNER JOIN renta.Negocio n ON n.negocio_id = c.negocio_id
 WHERE n.email_contacto IN ('neg06a@prueba.test', 'neg06b@prueba.test');
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba06.test';
DELETE FROM renta.Negocio WHERE email_contacto IN ('neg06a@prueba.test', 'neg06b@prueba.test');
GO

DECLARE @negA INT, @negB INT, @oper INT, @cli INT;
DECLARE @catSurf INT, @catBike INT, @catTemp INT;
DECLARE @surf1 INT, @surf2 INT, @bike1 INT, @temp INT, @x INT;
DECLARE @mant1 INT, @mant2 INT;

/* ---------- Preparacion ---------- */
EXEC renta.usp_Negocio_Crear @nombre = 'Negocio A 06', @email_contacto = 'neg06a@prueba.test', @negocio_id = @negA OUTPUT;
EXEC renta.usp_Negocio_Crear @nombre = 'Negocio B 06', @email_contacto = 'neg06b@prueba.test', @negocio_id = @negB OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo = 'Operador 06', @email = 'oper@prueba06.test',
     @password = N'Clave1234', @rol_nombre = 'Operador', @negocio_id = @negA, @usuario_id = @oper OUTPUT;
EXEC renta.usp_Usuario_Registrar @nombre_completo = 'Cliente 06', @email = 'cli@prueba06.test',
     @password = N'Clave1234', @usuario_id = @cli OUTPUT;

/* ======================= CATEGORIA EQUIPO ======================= */
PRINT '--- CategoriaEquipo: crear (esperado: 3 ids) ---';
EXEC renta.usp_CategoriaEquipo_Crear @negocio_id = @negA, @nombre = 'Tabla de Surf',
     @tarifa_hora = 15, @tarifa_dia = 50, @monto_deposito = 100, @categoria_id = @catSurf OUTPUT;
EXEC renta.usp_CategoriaEquipo_Crear @negocio_id = @negA, @nombre = 'Bicicleta',
     @descripcion = 'Bicicletas de montana', @tarifa_hora = 5, @tarifa_dia = 20, @monto_deposito = 50,
     @categoria_id = @catBike OUTPUT;
EXEC renta.usp_CategoriaEquipo_Crear @negocio_id = @negA, @nombre = 'Temporal',
     @tarifa_hora = 1, @tarifa_dia = 5, @monto_deposito = 0, @categoria_id = @catTemp OUTPUT;
SELECT @catSurf AS surf, @catBike AS bike, @catTemp AS temporal;

PRINT '--- CategoriaEquipo: modificar y obtener (esperado: Bicicleta con tarifa_hora 6) ---';
EXEC renta.usp_CategoriaEquipo_Modificar @categoria_id = @catBike, @negocio_id = @negA,
     @nombre = 'Bicicleta', @descripcion = 'Bicicletas de montana', @tarifa_hora = 6, @tarifa_dia = 20, @monto_deposito = 50;
EXEC renta.usp_CategoriaEquipo_ObtenerPorId @categoria_id = @catBike, @negocio_id = @negA;

PRINT '--- ERROR esperado 50002: nombre repetido ---';
BEGIN TRY
    EXEC renta.usp_CategoriaEquipo_Crear @negocio_id = @negA, @nombre = 'Tabla de Surf',
         @tarifa_hora = 15, @tarifa_dia = 50, @monto_deposito = 100, @categoria_id = @x OUTPUT;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50003: tarifa diaria menor que la de hora ---';
BEGIN TRY
    EXEC renta.usp_CategoriaEquipo_Crear @negocio_id = @negA, @nombre = 'Mala',
         @tarifa_hora = 30, @tarifa_dia = 10, @monto_deposito = 0, @categoria_id = @x OUTPUT;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- AISLAMIENTO, ERROR esperado 50001: el negocio B no ve la categoria del A ---';
BEGIN TRY
    EXEC renta.usp_CategoriaEquipo_ObtenerPorId @categoria_id = @catSurf, @negocio_id = @negB;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

/* ============================ EQUIPO ============================ */
PRINT '--- Equipo: crear (esperado: 4 ids) ---';
EXEC renta.usp_Equipo_Crear @negocio_id = @negA, @categoria_id = @catSurf, @codigo_interno = 'SURF-001',
     @descripcion = 'Tabla azul 7 pies', @fecha_adquisicion = '2026-01-15', @equipo_id = @surf1 OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id = @negA, @categoria_id = @catSurf, @codigo_interno = 'SURF-002',
     @equipo_id = @surf2 OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id = @negA, @categoria_id = @catBike, @codigo_interno = 'BIKE-001',
     @equipo_id = @bike1 OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id = @negA, @categoria_id = @catSurf, @codigo_interno = 'TEMP-001',
     @equipo_id = @temp OUTPUT;
SELECT @surf1 AS surf1, @surf2 AS surf2, @bike1 AS bike1, @temp AS temp;

PRINT '--- ERROR esperado 50002: codigo repetido en el negocio (aunque sea otra categoria) ---';
BEGIN TRY
    EXEC renta.usp_Equipo_Crear @negocio_id = @negA, @categoria_id = @catBike, @codigo_interno = 'SURF-001',
         @equipo_id = @x OUTPUT;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50001: categoria de otro negocio ---';
BEGIN TRY
    EXEC renta.usp_Equipo_Crear @negocio_id = @negB, @categoria_id = @catSurf, @codigo_interno = 'X-1',
         @equipo_id = @x OUTPUT;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Listar (esperado: 4 equipos) y filtrar por categoria Bicicleta (esperado: 1) ---';
EXEC renta.usp_Equipo_Listar @negocio_id = @negA;
EXEC renta.usp_Equipo_Listar @negocio_id = @negA, @categoria_id = @catBike;

PRINT '--- Modificar y obtener (esperado: SURF-002 con notas) ---';
EXEC renta.usp_Equipo_Modificar @equipo_id = @surf2, @negocio_id = @negA, @categoria_id = @catSurf,
     @codigo_interno = 'SURF-002', @descripcion = 'Tabla roja 6 pies', @notas = 'Aleta nueva';
EXEC renta.usp_Equipo_ObtenerPorId @equipo_id = @surf2, @negocio_id = @negA;

/* ===================== DISPONIBILIDAD ===================== */
PRINT '--- Disponibilidad 09:00-11:00 (esperado: 4 equipos; monto_estimado = 30 para los 3 de surf y 12 para la bicicleta) ---';
EXEC renta.usp_Equipo_ConsultarDisponibilidad @negocio_id = @negA,
     @fecha_inicio = '2026-12-10 09:00', @fecha_fin = '2026-12-10 11:00';

PRINT '--- ActualizarEstado: SURF-002 a Averiado (esperado: sin error) ---';
EXEC renta.usp_Equipo_ActualizarEstado @equipo_id = @surf2, @negocio_id = @negA,
     @nuevo_estado = 'Averiado', @usuario_id = @oper;

PRINT '--- ERROR esperado 50003: asignar Alquilado a mano ---';
BEGIN TRY
    EXEC renta.usp_Equipo_ActualizarEstado @equipo_id = @surf1, @negocio_id = @negA, @nuevo_estado = 'Alquilado';
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50003: asignar Mantenimiento a mano ---';
BEGIN TRY
    EXEC renta.usp_Equipo_ActualizarEstado @equipo_id = @surf1, @negocio_id = @negA, @nuevo_estado = 'Mantenimiento';
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50004: ya tiene ese estado ---';
BEGIN TRY
    EXEC renta.usp_Equipo_ActualizarEstado @equipo_id = @surf2, @negocio_id = @negA, @nuevo_estado = 'Averiado';
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

/* Simulamos una reserva activa sobre SURF-001 (la creacion real llega en el script 09) */
DECLARE @res INT;
INSERT INTO renta.Reserva (negocio_id, cliente_id, operador_id, tipo_reserva, estado, fecha_inicio, fecha_fin, monto_final)
VALUES (@negA, @cli, @oper, 'Anticipada', 'Confirmada', '2026-12-10 09:00', '2026-12-10 12:00', 45);
SET @res = SCOPE_IDENTITY();
INSERT INTO renta.DetalleReserva (reserva_id, equipo_id, tarifa_aplicada) VALUES (@res, @surf1, 45);
UPDATE renta.Equipo SET estado = 'Reservado' WHERE equipo_id = @surf1;

PRINT '--- Disponibilidad con SURF-001 reservado y SURF-002 averiado (esperado: BIKE-001 y TEMP-001) ---';
EXEC renta.usp_Equipo_ConsultarDisponibilidad @negocio_id = @negA,
     @fecha_inicio = '2026-12-10 10:00', @fecha_fin = '2026-12-10 11:00';

PRINT '--- fn_EquipoEstaDisponible: SURF-001 = 0, SURF-002 = 0, BIKE-001 = 1 ---';
SELECT renta.fn_EquipoEstaDisponible(@surf1, '2026-12-10 10:00', '2026-12-10 11:00') AS surf1_reservado,
       renta.fn_EquipoEstaDisponible(@surf2, '2026-12-10 10:00', '2026-12-10 11:00') AS surf2_averiado,
       renta.fn_EquipoEstaDisponible(@bike1, '2026-12-10 10:00', '2026-12-10 11:00') AS bike1_libre,
       renta.fn_EquipoEstaDisponible(@surf1, '2026-12-11 10:00', '2026-12-11 11:00') AS surf1_otro_dia; -- esperado 1 (otro dia)

PRINT '--- ERROR esperado 50003: rango de fechas invertido ---';
BEGIN TRY
    EXEC renta.usp_Equipo_ConsultarDisponibilidad @negocio_id = @negA,
         @fecha_inicio = '2026-12-10 11:00', @fecha_fin = '2026-12-10 09:00';
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

/* ======================== MANTENIMIENTO ======================== */
PRINT '--- Mantenimiento_Crear sobre BIKE-001 (esperado: id y equipo en estado Mantenimiento) ---';
EXEC renta.usp_Mantenimiento_Crear @negocio_id = @negA, @equipo_id = @bike1, @operador_id = @oper,
     @tipo = 'Preventivo', @descripcion = 'Cambio de frenos', @costo = 25, @mantenimiento_id = @mant1 OUTPUT;
SELECT @mant1 AS mantenimiento_id;
EXEC renta.usp_Equipo_ObtenerPorId @equipo_id = @bike1, @negocio_id = @negA;

PRINT '--- ERROR esperado 50004: mantenimiento sobre equipo Reservado (SURF-001) ---';
BEGIN TRY
    EXEC renta.usp_Mantenimiento_Crear @negocio_id = @negA, @equipo_id = @surf1, @operador_id = @oper,
         @tipo = 'Correctivo', @mantenimiento_id = @x OUTPUT;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50004: BIKE-001 ya esta en Mantenimiento ---';
BEGIN TRY
    EXEC renta.usp_Mantenimiento_Crear @negocio_id = @negA, @equipo_id = @bike1, @operador_id = @oper,
         @tipo = 'Correctivo', @mantenimiento_id = @x OUTPUT;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50001: operador de otro negocio (la transaccion no deja nada a medias) ---';
BEGIN TRY
    EXEC renta.usp_Mantenimiento_Crear @negocio_id = @negB, @equipo_id = @bike1, @operador_id = @oper,
         @tipo = 'Correctivo', @mantenimiento_id = @x OUTPUT;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Listar solo abiertos (esperado: 1) ---';
EXEC renta.usp_Mantenimiento_Listar @negocio_id = @negA, @solo_abiertos = 1;

PRINT '--- Modificar mantenimiento (esperado: costo 30) ---';
EXEC renta.usp_Mantenimiento_Modificar @mantenimiento_id = @mant1, @negocio_id = @negA,
     @tipo = 'Preventivo', @descripcion = 'Frenos y cadena', @costo = 30;
EXEC renta.usp_Mantenimiento_ObtenerPorId @mantenimiento_id = @mant1, @negocio_id = @negA;

PRINT '--- ERROR esperado 50004: eliminar un mantenimiento abierto ---';
BEGIN TRY
    EXEC renta.usp_Mantenimiento_Eliminar @mantenimiento_id = @mant1, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Finalizar (esperado: equipo vuelve a Disponible) ---';
EXEC renta.usp_Mantenimiento_Finalizar @mantenimiento_id = @mant1, @negocio_id = @negA, @usuario_id = @oper;
EXEC renta.usp_Equipo_ObtenerPorId @equipo_id = @bike1, @negocio_id = @negA;

PRINT '--- ERROR esperado 50004: finalizar dos veces ---';
BEGIN TRY
    EXEC renta.usp_Mantenimiento_Finalizar @mantenimiento_id = @mant1, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Mantenimiento de SURF-002 (Averiado) que termina Fuera de servicio ---';
EXEC renta.usp_Mantenimiento_Crear @negocio_id = @negA, @equipo_id = @surf2, @operador_id = @oper,
     @tipo = 'Correctivo', @descripcion = 'Quilla rota', @costo = 80, @mantenimiento_id = @mant2 OUTPUT;
EXEC renta.usp_Mantenimiento_Finalizar @mantenimiento_id = @mant2, @negocio_id = @negA,
     @estado_equipo = 'Fuera de servicio', @usuario_id = @oper;
EXEC renta.usp_Equipo_ObtenerPorId @equipo_id = @surf2, @negocio_id = @negA;   -- esperado: Fuera de servicio
PRINT '--- Auditoria automatica de SURF-002 (esperado: Averiado, Mantenimiento, Fuera de servicio) ---';
SELECT a.auditoria_id, a.equipo_id, e.codigo_interno, a.estado_anterior, a.estado_nuevo, a.fecha_hora
FROM renta.AuditoriaEquipo AS a
INNER JOIN renta.Equipo AS e ON e.equipo_id = a.equipo_id
WHERE a.equipo_id = @surf2
ORDER BY a.fecha_hora, a.auditoria_id;

PRINT '--- Eliminar mantenimiento finalizado (esperado: sin error) ---';
EXEC renta.usp_Mantenimiento_Eliminar @mantenimiento_id = @mant2, @negocio_id = @negA;

/* ======================== ELIMINAR ======================== */
PRINT '--- ERROR esperado 50002: eliminar equipo con historial (BIKE-001) ---';
BEGIN TRY
    EXEC renta.usp_Equipo_Eliminar @equipo_id = @bike1, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- ERROR esperado 50002: eliminar categoria con equipos ---';
BEGIN TRY
    EXEC renta.usp_CategoriaEquipo_Eliminar @categoria_id = @catSurf, @negocio_id = @negA;
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje; END CATCH

PRINT '--- Eliminar equipo sin historial y categoria vacia (esperado: sin error) ---';
EXEC renta.usp_Equipo_Eliminar @equipo_id = @temp, @negocio_id = @negA;
EXEC renta.usp_CategoriaEquipo_Eliminar @categoria_id = @catTemp, @negocio_id = @negA;
EXEC renta.usp_CategoriaEquipo_Listar @negocio_id = @negA;   -- esperado: 2 categorias (Surf con 2 equipos, Bicicleta con 1)

/* ---------- Limpieza final ---------- */
DELETE FROM renta.DetalleReserva WHERE reserva_id = @res;
DELETE FROM renta.Reserva WHERE reserva_id = @res;
DELETE m FROM renta.Mantenimiento m INNER JOIN renta.Equipo e ON e.equipo_id = m.equipo_id
 INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id WHERE c.negocio_id = @negA;
DELETE a FROM renta.AuditoriaEquipo a INNER JOIN renta.Equipo e ON e.equipo_id = a.equipo_id
 INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id WHERE c.negocio_id = @negA;
DELETE e FROM renta.Equipo e INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id WHERE c.negocio_id = @negA;
DELETE FROM renta.CategoriaEquipo WHERE negocio_id = @negA;
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba06.test';
DELETE FROM renta.Negocio WHERE negocio_id IN (@negA, @negB);
PRINT 'Pruebas del script 06 finalizadas y base limpia.';
GO
