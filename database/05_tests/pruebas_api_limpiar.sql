/* Limpia el escenario temporal creado por pruebas_api_preparar.sql. */
USE RentaTicaDB;
GO
SET NOCOUNT ON;
DELETE a FROM renta.AuditoriaEquipo a
JOIN renta.Equipo e ON e.equipo_id=a.equipo_id
JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
WHERE n.email_contacto='api@prueba.test';
DELETE e FROM renta.Equipo e
JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
WHERE n.email_contacto='api@prueba.test';
DELETE c FROM renta.CategoriaEquipo c
JOIN renta.Negocio n ON n.negocio_id=c.negocio_id
WHERE n.email_contacto='api@prueba.test';
DELETE FROM renta.Usuario WHERE email='operador@api.prueba.test';
DELETE FROM renta.Negocio WHERE email_contacto='api@prueba.test';
GO