/* ============================================================================
   Pruebas del script 02_datos_iniciales.sql
   ============================================================================
   Resultado esperado:
     - Rol:        3 filas (Administrador, Operador, Cliente)
     - MetodoPago: 3 filas (Efectivo, SINPE Movil, Tarjeta)
   ============================================================================ */

USE RentaTicaDB;
GO

SELECT * FROM renta.Rol ORDER BY rol_id;
SELECT * FROM renta.MetodoPago ORDER BY metodo_pago_id;
GO

/* Re-ejecutar el script 02 no debe duplicar datos: este conteo debe seguir en 3 y 3 */
SELECT (SELECT COUNT(*) FROM renta.Rol)        AS total_roles,
       (SELECT COUNT(*) FROM renta.MetodoPago) AS total_metodos_pago;
GO