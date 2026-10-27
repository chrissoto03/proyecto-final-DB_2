/* ============================================================================
   00_base_datos_y_esquema.sql
   RentaTica - Creacion de la base de datos y del esquema [renta]
   Universidad Latina de Costa Rica - BTI23 Bases de Datos II
   ============================================================================
   Re-ejecutable: no borra nada si la base de datos ya existe.
   Todos los objetos del proyecto viven en el esquema [renta] (nunca en dbo).

   CONVENCIONES DEL PROYECTO (aplican a todos los scripts)
   --------------------------------------------------------------------------
   Nombres:   usp_<Entidad>_<Accion>   Ej: usp_Negocio_Crear
              fn_<Nombre>              funciones
              trg_<Tabla>_<Accion>     triggers
   Acciones CRUD por entidad: Crear, Modificar, Eliminar, ObtenerPorId, Listar
   (mas acciones especificas como CambiarEstado cuando aplica).

   Codigos de error propios (THROW). El API los traduce a codigos HTTP:
     50001  El registro no existe ................. HTTP 404
     50002  Conflicto (duplicado o con dependencias) HTTP 409
     50003  Datos invalidos / validacion ........... HTTP 400
     50004  Operacion no permitida por regla de negocio / estado .. HTTP 422
     50005  Credenciales invalidas (login o cambio de contrasena) . HTTP 401
   Cualquier otro error de SQL Server => HTTP 500.

   Todo SP inicia con SET NOCOUNT ON, usa TRY...CATCH y lleva un comentario
   de cabecera con nombre, descripcion, parametros, autor y fecha.
   ============================================================================ */

USE master;
GO

IF DB_ID('RentaTicaDB') IS NULL
BEGIN
    CREATE DATABASE RentaTicaDB;
    PRINT 'Base de datos RentaTicaDB creada.';
END
ELSE
    PRINT 'La base de datos RentaTicaDB ya existe.';
GO

USE RentaTicaDB;
GO

IF SCHEMA_ID('renta') IS NULL
BEGIN
    EXEC('CREATE SCHEMA renta');
    PRINT 'Esquema renta creado.';
END
ELSE
    PRINT 'El esquema renta ya existe.';
GO