/* ============================================================================
   Pruebas del script 04_sp_crud_catalogos_negocio.sql
   ============================================================================
   Ejecutar DESPUES de los scripts 00, 01, 02 y 04.
   Cada bloque indica el resultado esperado. Los bloques de "ERROR esperado"
   deben mostrar el numero de error y mensaje indicados (no deben romper el
   script). Las pruebas dejan la base como estaba: crean y luego eliminan.
   ============================================================================ */

USE RentaTicaDB;
GO

/* ############################ ROL ############################ */

PRINT '--- Rol: crear, modificar, consultar, listar, eliminar ---';
DECLARE @rol_id INT;

EXEC renta.usp_Rol_Crear @nombre = 'Supervisor', @rol_id = @rol_id OUTPUT;
SELECT @rol_id AS rol_creado;                              -- esperado: un id (ej. 4)

EXEC renta.usp_Rol_Modificar @rol_id = @rol_id, @nombre = 'Supervisor de sucursal';
EXEC renta.usp_Rol_ObtenerPorId @rol_id = @rol_id;         -- esperado: nombre 'Supervisor de sucursal'
EXEC renta.usp_Rol_Listar;                                 -- esperado: 4 roles

EXEC renta.usp_Rol_Eliminar @rol_id = @rol_id;             -- esperado: sin error
GO

PRINT '--- Rol: ERROR esperado 50002 (duplicado) ---';
BEGIN TRY
    DECLARE @x INT;
    EXEC renta.usp_Rol_Crear @nombre = 'Cliente', @rol_id = @x OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;   -- 50002
END CATCH
GO

PRINT '--- Rol: ERROR esperado 50004 (rol base protegido) ---';
BEGIN TRY
    EXEC renta.usp_Rol_Eliminar @rol_id = 1;   -- Administrador
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;   -- 50004
END CATCH
GO

PRINT '--- Rol: ERROR esperado 50001 (no existe) ---';
BEGIN TRY
    EXEC renta.usp_Rol_ObtenerPorId @rol_id = 9999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;   -- 50001
END CATCH
GO

/* ######################## METODO DE PAGO ######################## */

PRINT '--- MetodoPago: crear, modificar, consultar, listar, eliminar ---';
DECLARE @mp_id INT, @mp_total_antes INT;
DECLARE @mp_nombre VARCHAR(30), @mp_nombre_modificado VARCHAR(30);
SELECT @mp_total_antes = COUNT(*) FROM renta.MetodoPago;
SET @mp_nombre = 'T04-' + LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 12);
SET @mp_nombre_modificado = @mp_nombre + '-MOD';

/* Ejecutar el bloque completo hasta GO: @mp_id vive dentro de este lote. */
EXEC renta.usp_MetodoPago_Crear @nombre = @mp_nombre, @metodo_pago_id = @mp_id OUTPUT;
SELECT @mp_id AS metodo_creado, @mp_nombre AS nombre_prueba; -- esperado: un id y nombre T04-...

EXEC renta.usp_MetodoPago_Modificar @metodo_pago_id = @mp_id, @nombre = @mp_nombre_modificado;
EXEC renta.usp_MetodoPago_ObtenerPorId @metodo_pago_id = @mp_id;
EXEC renta.usp_MetodoPago_Listar;                          -- incluye el metodo modificado
SELECT COUNT(*) AS total_metodos, @mp_total_antes + 1 AS total_esperado FROM renta.MetodoPago;

EXEC renta.usp_MetodoPago_Eliminar @metodo_pago_id = @mp_id;
SELECT COUNT(*) AS total_despues_de_limpiar, @mp_total_antes AS total_esperado FROM renta.MetodoPago;
GO

PRINT '--- MetodoPago: ERROR esperado 50002 (duplicado) ---';
BEGIN TRY
    DECLARE @y INT;
    EXEC renta.usp_MetodoPago_Crear @nombre = 'Efectivo', @metodo_pago_id = @y OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;   -- 50002
END CATCH
GO

/* ############################ NEGOCIO ############################ */

PRINT '--- Negocio: ciclo completo ---';
DECLARE @neg_id INT;

EXEC renta.usp_Negocio_Crear
    @nombre         = 'Tamarindo Surf Rentals',
    @direccion      = 'Tamarindo, Guanacaste',
    @telefono       = '8888-1111',
    @email_contacto = 'info@tamarindosurf.test',
    @negocio_id     = @neg_id OUTPUT;
SELECT @neg_id AS negocio_creado;

EXEC renta.usp_Negocio_Modificar
    @negocio_id     = @neg_id,
    @nombre         = 'Tamarindo Surf & Bike Rentals',
    @direccion      = 'Av. Central, Tamarindo',
    @telefono       = '8888-1111',
    @email_contacto = 'info@tamarindosurf.test';

EXEC renta.usp_Negocio_ObtenerPorId @negocio_id = @neg_id;   -- esperado: nombre nuevo, estado Activo

EXEC renta.usp_Negocio_CambiarEstado @negocio_id = @neg_id, @estado = 'Suspendido';
EXEC renta.usp_Negocio_Listar @estado = 'Suspendido';        -- esperado: incluye el negocio
EXEC renta.usp_Negocio_Listar @estado = 'Activo';            -- esperado: NO lo incluye
EXEC renta.usp_Negocio_Listar;                               -- esperado: todos

EXEC renta.usp_Negocio_Eliminar @negocio_id = @neg_id;       -- esperado: sin error (no tiene datos)
GO

PRINT '--- Negocio: ERROR esperado 50002 (correo duplicado) ---';
DECLARE @n1 INT, @n2 INT;
EXEC renta.usp_Negocio_Crear @nombre = 'Negocio A', @email_contacto = 'dup@test.com', @negocio_id = @n1 OUTPUT;
BEGIN TRY
    EXEC renta.usp_Negocio_Crear @nombre = 'Negocio B', @email_contacto = 'dup@test.com', @negocio_id = @n2 OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;   -- 50002
END CATCH
EXEC renta.usp_Negocio_Eliminar @negocio_id = @n1;   -- limpieza
GO

PRINT '--- Negocio: ERROR esperado 50003 (estado invalido) ---';
BEGIN TRY
    EXEC renta.usp_Negocio_CambiarEstado @negocio_id = 1, @estado = 'Cerrado';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;   -- 50003
END CATCH
GO

PRINT '--- Negocio: ERROR esperado 50001 (no existe) ---';
BEGIN TRY
    EXEC renta.usp_Negocio_ObtenerPorId @negocio_id = 9999;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero, ERROR_MESSAGE() AS mensaje;   -- 50001
END CATCH
GO
