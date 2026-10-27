/* ============================================================================
   Pruebas del script 05_sp_crud_usuarios.sql
   ============================================================================
   Ejecutar despues de instalar los scripts 00 a 10.
   En SSMS, ejecutar el archivo completo con Ctrl+A y F5. Si se ejecuta por
   secciones, incluir desde las declaraciones DECLARE hasta el GO final.
   Las variables @neg, @admin, @oper, @cli y @cli2 solo existen dentro de ese
   lote; ejecutar una seleccion que empiece despues de los DECLARE produce
   Msg 137 (variable no declarada).
   El script es re-ejecutable: al inicio borra los datos de pruebas anteriores
   y al final deja la base limpia.
   Los bloques "ERROR esperado" deben mostrar el numero y mensaje indicados.
   ============================================================================ */

USE RentaTicaDB;
GO

/* ---------- Limpieza previa ---------- */
DELETE r FROM renta.Reserva r
INNER JOIN renta.Negocio n ON n.negocio_id = r.negocio_id
WHERE n.email_contacto = 'neg05@prueba.test';
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba05.test';
DELETE FROM renta.Negocio WHERE email_contacto = 'neg05@prueba.test';
GO

DECLARE @neg INT, @admin INT, @oper INT, @cli INT, @cli2 INT, @x INT;
DECLARE @rolOperador INT = (SELECT rol_id FROM renta.Rol WHERE nombre = 'Operador');
DECLARE @rolCliente  INT = (SELECT rol_id FROM renta.Rol WHERE nombre = 'Cliente');

PRINT 'Lote de pruebas iniciado: conservar estas declaraciones hasta el GO final.';

/* ---------- Preparacion: un negocio ---------- */
EXEC renta.usp_Negocio_Crear
    @nombre = 'Negocio Prueba 05', @email_contacto = 'neg05@prueba.test', @negocio_id = @neg OUTPUT;

/* ---------- Crear: empleados y cliente ---------- */
PRINT '--- Crear empleados y cliente (esperado: 3 ids) ---';
EXEC renta.usp_Usuario_CrearEmpleado
    @nombre_completo = 'Admin Prueba', @email = 'admin@prueba05.test', @password = N'Clave1234',
    @telefono = '8888-0001', @rol_nombre = 'Administrador', @negocio_id = @neg, @usuario_id = @admin OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado
    @nombre_completo = 'Operador Prueba', @email = 'oper@prueba05.test', @password = N'Clave1234',
    @rol_nombre = 'Operador', @negocio_id = @neg, @usuario_id = @oper OUTPUT;
EXEC renta.usp_Usuario_Registrar
    @nombre_completo = 'Cliente Prueba', @email = 'cli@prueba05.test', @password = N'Clave1234',
    @documento_identidad = 'PASAPORTE-123', @usuario_id = @cli OUTPUT;
EXEC renta.usp_Usuario_Registrar
    @nombre_completo = 'Cliente Dos', @email = 'cli2@prueba05.test', @password = N'Clave1234',
    @usuario_id = @cli2 OUTPUT;
SELECT @admin AS admin_id, @oper AS operador_id, @cli AS cliente_id, @cli2 AS cliente2_id;

/* ---------- La contrasena nunca se guarda en texto plano ---------- */
PRINT '--- password_hash debe verse como salt:hash, NO como Clave1234 ---';
SELECT usuario_id, email, password_hash FROM renta.Usuario WHERE usuario_id = @admin;

/* ---------- Autenticacion ---------- */
PRINT '--- Login correcto (esperado: 1 fila, rol Administrador) ---';
EXEC renta.usp_Auth_ValidarCredenciales @email = 'admin@prueba05.test', @password = N'Clave1234';

PRINT '--- ERROR esperado 50005: contrasena incorrecta ---';
BEGIN TRY
    EXEC renta.usp_Auth_ValidarCredenciales @email = 'admin@prueba05.test', @password = N'Incorrecta99';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50005: correo inexistente (mismo mensaje) ---';
BEGIN TRY
    EXEC renta.usp_Auth_ValidarCredenciales @email = 'nadie@prueba05.test', @password = N'Clave1234';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50004: negocio suspendido ---';
EXEC renta.usp_Negocio_CambiarEstado @negocio_id = @neg, @estado = 'Suspendido';
BEGIN TRY
    EXEC renta.usp_Auth_ValidarCredenciales @email = 'oper@prueba05.test', @password = N'Clave1234';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH
EXEC renta.usp_Negocio_CambiarEstado @negocio_id = @neg, @estado = 'Activo';

PRINT '--- Un cliente sin negocio si puede entrar aunque haya negocios suspendidos (esperado: 1 fila) ---';
EXEC renta.usp_Auth_ValidarCredenciales @email = 'cli@prueba05.test', @password = N'Clave1234';

/* ---------- Validaciones de creacion ---------- */
PRINT '--- ERROR esperado 50002: correo duplicado ---';
BEGIN TRY
    EXEC renta.usp_Usuario_Registrar @nombre_completo = 'Otro', @email = 'cli@prueba05.test',
         @password = N'Clave1234', @usuario_id = @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50003: contrasena corta ---';
BEGIN TRY
    EXEC renta.usp_Usuario_Registrar @nombre_completo = 'Otro', @email = 'corta@prueba05.test',
         @password = N'123', @usuario_id = @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50003: correo con formato invalido ---';
BEGIN TRY
    EXEC renta.usp_Usuario_Registrar @nombre_completo = 'Otro', @email = 'esto-no-es-un-correo',
         @password = N'Clave1234', @usuario_id = @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50003: personal sin negocio ---';
BEGIN TRY
    EXEC renta.usp_Usuario_Crear @nombre_completo = 'Sin negocio', @email = 'sn@prueba05.test',
         @password = N'Clave1234', @rol_id = @rolOperador, @negocio_id = NULL, @usuario_id = @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50003: cliente con negocio ---';
BEGIN TRY
    EXEC renta.usp_Usuario_Crear @nombre_completo = 'Cliente con negocio', @email = 'cn@prueba05.test',
         @password = N'Clave1234', @rol_id = @rolCliente, @negocio_id = @neg, @usuario_id = @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50003: CrearEmpleado con rol Cliente ---';
BEGIN TRY
    EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo = 'X', @email = 'x@prueba05.test',
         @password = N'Clave1234', @rol_nombre = 'Cliente', @negocio_id = @neg, @usuario_id = @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

/* ---------- Consultas ---------- */
PRINT '--- ObtenerPorId (esperado: 1 fila, SIN columna password_hash) ---';
EXEC renta.usp_Usuario_ObtenerPorId @usuario_id = @admin;

PRINT '--- Listar personal del negocio (esperado: 2 filas) ---';
EXEC renta.usp_Usuario_Listar @negocio_id = @neg;

PRINT '--- Listar solo clientes (esperado: al menos 2 filas) ---';
EXEC renta.usp_Usuario_Listar @rol_id = @rolCliente;

PRINT '--- ERROR esperado 50001: usuario inexistente ---';
BEGIN TRY
    EXEC renta.usp_Usuario_ObtenerPorId @usuario_id = 999999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

/* ---------- Modificar ---------- */
PRINT '--- Modificar (esperado: nombre y telefono nuevos) ---';
EXEC renta.usp_Usuario_Modificar @usuario_id = @oper, @nombre_completo = 'Operador Modificado',
     @email = 'oper@prueba05.test', @telefono = '8888-9999';
EXEC renta.usp_Usuario_ObtenerPorId @usuario_id = @oper;

PRINT '--- ERROR esperado 50002: modificar con correo de otro usuario ---';
BEGIN TRY
    EXEC renta.usp_Usuario_Modificar @usuario_id = @oper, @nombre_completo = 'Operador Modificado',
         @email = 'admin@prueba05.test';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

/* ---------- Cambiar contrasena ---------- */
PRINT '--- CambiarPassword y login con la nueva (esperado: 1 fila) ---';
EXEC renta.usp_Usuario_CambiarPassword @usuario_id = @oper,
     @password_actual = N'Clave1234', @password_nueva = N'NuevaClave99';
EXEC renta.usp_Auth_ValidarCredenciales @email = 'oper@prueba05.test', @password = N'NuevaClave99';

PRINT '--- ERROR esperado 50005: la contrasena vieja ya no entra ---';
BEGIN TRY
    EXEC renta.usp_Auth_ValidarCredenciales @email = 'oper@prueba05.test', @password = N'Clave1234';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50005: contrasena actual incorrecta al cambiar ---';
BEGIN TRY
    EXEC renta.usp_Usuario_CambiarPassword @usuario_id = @oper,
         @password_actual = N'Mala12345', @password_nueva = N'OtraClave99';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

/* ---------- Cambiar rol ---------- */
PRINT '--- CambiarRol: cliente2 pasa a Operador del negocio (esperado: rol Operador) ---';
EXEC renta.usp_Usuario_CambiarRol @usuario_id = @cli2, @rol_id = @rolOperador, @negocio_id = @neg;
EXEC renta.usp_Usuario_ObtenerPorId @usuario_id = @cli2;

PRINT '--- ERROR esperado 50003: volver a Cliente conservando negocio ---';
BEGIN TRY
    EXEC renta.usp_Usuario_CambiarRol @usuario_id = @cli2, @rol_id = @rolCliente, @negocio_id = @neg;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- CambiarRol: volver a Cliente sin negocio (esperado: rol Cliente) ---';
EXEC renta.usp_Usuario_CambiarRol @usuario_id = @cli2, @rol_id = @rolCliente, @negocio_id = NULL;
EXEC renta.usp_Usuario_ObtenerPorId @usuario_id = @cli2;

/* ---------- Eliminar con y sin historial ---------- */
INSERT INTO renta.Reserva (negocio_id, cliente_id, operador_id, tipo_reserva, fecha_inicio, fecha_fin)
VALUES (@neg, @cli, @oper, 'Walk-in', '2026-10-10 09:00', '2026-10-10 11:00');

PRINT '--- ERROR esperado 50004: cliente con reservas no puede pasar a personal ---';
BEGIN TRY
    EXEC renta.usp_Usuario_CambiarRol @usuario_id = @cli, @rol_id = @rolOperador, @negocio_id = @neg;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- ERROR esperado 50002: eliminar usuario con historial ---';
BEGIN TRY
    EXEC renta.usp_Usuario_Eliminar @usuario_id = @cli;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;
END CATCH

PRINT '--- Eliminar usuario sin historial (esperado: sin error) ---';
EXEC renta.usp_Usuario_Eliminar @usuario_id = @cli2;

/* ---------- Limpieza final ---------- */
DELETE FROM renta.Reserva WHERE negocio_id = @neg;
DELETE FROM renta.Usuario WHERE email LIKE '%@prueba05.test';
EXEC renta.usp_Negocio_Eliminar @negocio_id = @neg;
PRINT 'Pruebas del script 05 finalizadas y base limpia.';
GO
