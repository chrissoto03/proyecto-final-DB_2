/* ============================================================================
   02_datos_iniciales.sql
   RentaTica - Datos de catalogo obligatorios para que el sistema funcione
   ============================================================================
   Requiere: todas las tablas de 00_schema/01_tablas/ instaladas.
   Re-ejecutable: solo inserta lo que falta.
   No se insertan negocios ni usuarios de demostracion.

   ============================================================================ */

USE RentaTicaDB;
GO

/* Roles base del sistema. Los stored procedures y el trigger de Usuario
   dependen de estos tres nombres exactos. */
INSERT INTO renta.Rol (nombre)
SELECT v.nombre
FROM (VALUES ('Administrador'), ('Operador'), ('Cliente')) AS v(nombre)
WHERE NOT EXISTS (SELECT 1 FROM renta.Rol r WHERE r.nombre = v.nombre);
GO

/* Metodos de pago iniciales. */
INSERT INTO renta.MetodoPago (nombre)
SELECT v.nombre
FROM (VALUES ('Efectivo'), ('Tarjeta'), ('SINPE Movil')) AS v(nombre)
WHERE NOT EXISTS (SELECT 1 FROM renta.MetodoPago m WHERE m.nombre = v.nombre);
GO

