/* Limpia solo el escenario temporal de rendimiento R4 por su correo identificador. */
USE RentaTicaDB;
GO
SET NOCOUNT ON;
DECLARE @negocio_id INT=(SELECT negocio_id FROM renta.Negocio WHERE email_contacto='r4-benchmark@prueba.test');
IF @negocio_id IS NULL
BEGIN
    PRINT 'No existe el negocio temporal R4; no hay nada que limpiar.';
    RETURN;
END;
DELETE p FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id WHERE r.negocio_id=@negocio_id;
DELETE d FROM renta.Deposito d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id WHERE r.negocio_id=@negocio_id;
DELETE dr FROM renta.DetalleReserva dr JOIN renta.Reserva r ON r.reserva_id=dr.reserva_id WHERE r.negocio_id=@negocio_id;
DELETE FROM renta.Reserva WHERE negocio_id=@negocio_id;
DELETE a FROM renta.AuditoriaEquipo a JOIN renta.Equipo e ON e.equipo_id=a.equipo_id
  JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@negocio_id;
DELETE m FROM renta.Mantenimiento m JOIN renta.Equipo e ON e.equipo_id=m.equipo_id
  JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@negocio_id;
DELETE e FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@negocio_id;
DELETE FROM renta.CategoriaEquipo WHERE negocio_id=@negocio_id;
DELETE FROM renta.Usuario WHERE negocio_id=@negocio_id OR email='r4-benchmark-cliente@prueba.test';
DELETE FROM renta.Negocio WHERE negocio_id=@negocio_id;
PRINT 'Escenario temporal R4 eliminado.';
GO
