/* ============================================================================
   Pruebas del script 03_funciones.sql
   ============================================================================
   Ejecutar despues de los scripts 00 a 03.
   fn_EquipoEstaDisponible y fn_EquiposDisponibles dependen de reservas y
   equipos, asi que se prueban en pruebas/06_prueba_crud_equipos.sql.
   ============================================================================ */

USE RentaTicaDB;
GO

/* ---------- fn_CalcularMontoAlquiler (tarifa_hora = 15, tarifa_dia = 50) ---------- */
SELECT
    renta.fn_CalcularMontoAlquiler(15, 50, '2026-10-10 09:00', '2026-10-10 11:00') AS dos_horas,        -- esperado 30.00
    renta.fn_CalcularMontoAlquiler(15, 50, '2026-10-10 09:00', '2026-10-10 13:00') AS cuatro_horas,     -- esperado 50.00 (tope diario)
    renta.fn_CalcularMontoAlquiler(15, 50, '2026-10-10 09:00', '2026-10-10 09:30') AS media_hora,       -- esperado 15.00 (hora iniciada)
    renta.fn_CalcularMontoAlquiler(15, 50, '2026-10-10 09:00', '2026-10-11 09:00') AS un_dia,           -- esperado 50.00
    renta.fn_CalcularMontoAlquiler(15, 50, '2026-10-10 09:00', '2026-10-11 11:00') AS un_dia_dos_horas, -- esperado 80.00
    renta.fn_CalcularMontoAlquiler(15, 50, '2026-10-10 09:00', '2026-10-10 08:00') AS rango_invalido;   -- esperado 0.00
GO

/* ---------- fn_HashPassword y fn_VerificarPassword ---------- */
SELECT renta.fn_HashPassword(N'Clave1234', 'abc123') AS hash_guardado;
-- esperado: texto 'abc123:' seguido de 64 caracteres hexadecimales

SELECT LEN(renta.fn_HashPassword(N'Clave1234', 'abc123')) AS longitud;           -- esperado 71

DECLARE @guardado VARCHAR(256) = renta.fn_HashPassword(N'Clave1234', 'abc123');
SELECT
    renta.fn_VerificarPassword(N'Clave1234', @guardado) AS correcta,             -- esperado 1
    renta.fn_VerificarPassword(N'otraClave', @guardado) AS incorrecta,           -- esperado 0
    renta.fn_VerificarPassword(N'Clave1234', NULL)       AS sin_hash,            -- esperado 0
    renta.fn_VerificarPassword(N'Clave1234', 'sin-formato') AS formato_malo;     -- esperado 0

/* mismo password con salt distinto debe dar hash distinto */
SELECT CASE WHEN renta.fn_HashPassword(N'Clave1234', 'salt1')
               <> renta.fn_HashPassword(N'Clave1234', 'salt2')
            THEN 'OK: hashes distintos' ELSE 'ERROR: hashes iguales' END AS prueba_salt;
GO

/* ---------- fn_RolRequiereNegocio ---------- */
SELECT r.rol_id, r.nombre, renta.fn_RolRequiereNegocio(r.rol_id) AS requiere_negocio
FROM renta.Rol r
ORDER BY r.rol_id;
-- esperado: Administrador = 1, Operador = 1, Cliente = 0

SELECT renta.fn_RolRequiereNegocio(9999) AS rol_inexistente;   -- esperado 0
GO