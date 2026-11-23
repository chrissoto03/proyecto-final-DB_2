/*
  Escenario aislado para probar en Swagger y en el cliente .NET el ciclo de alquiler.
  Prepara operador, cliente y tres equipos disponibles (`FLUJO-001` a `FLUJO-003`). Al repetirlo, reemplaza solo el negocio
  identificado por api-flujo@prueba.test y sus filas asociadas.
  Ejecute en RentaTicaDB después de instalar el esquema, SPs y datos iniciales.
*/
USE RentaTicaDB;
GO
SET NOCOUNT ON;
DECLARE @old_negocio_id INT=(SELECT negocio_id FROM renta.Negocio WHERE email_contacto='api-flujo@prueba.test');
IF @old_negocio_id IS NOT NULL
BEGIN
    DELETE p FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id WHERE r.negocio_id=@old_negocio_id;
    DELETE d FROM renta.Deposito d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id WHERE r.negocio_id=@old_negocio_id;
    DELETE dr FROM renta.DetalleReserva dr JOIN renta.Reserva r ON r.reserva_id=dr.reserva_id WHERE r.negocio_id=@old_negocio_id;
    DELETE FROM renta.Reserva WHERE negocio_id=@old_negocio_id;
    DELETE a FROM renta.AuditoriaEquipo a JOIN renta.Equipo e ON e.equipo_id=a.equipo_id
      JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@old_negocio_id;
    DELETE m FROM renta.Mantenimiento m JOIN renta.Equipo e ON e.equipo_id=m.equipo_id
      JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@old_negocio_id;
    DELETE e FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@old_negocio_id;
    DELETE FROM renta.CategoriaEquipo WHERE negocio_id=@old_negocio_id;
    DELETE FROM renta.Usuario WHERE negocio_id=@old_negocio_id OR email='cliente.flujo@prueba.test';
    DELETE FROM renta.Negocio WHERE negocio_id=@old_negocio_id;
END;
IF NOT EXISTS(SELECT 1 FROM renta.MetodoPago WHERE nombre='Efectivo')
    THROW 51020,'No existe el metodo Efectivo; ejecute los datos iniciales.',1;
GO
DECLARE @negocio_id INT,@operador_id INT,@cliente_id INT,@categoria_id INT,@equipo_id INT,@equipo_id_2 INT,@equipo_id_3 INT;
EXEC renta.usp_Negocio_Crear @nombre='Negocio prueba flujo API',@email_contacto='api-flujo@prueba.test',@negocio_id=@negocio_id OUTPUT;
EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo='Operador prueba flujo',@email='operador.flujo@prueba.test',
  @password=N'RentaTicaFlujo2026!',@rol_nombre='Operador',@negocio_id=@negocio_id,@usuario_id=@operador_id OUTPUT;
EXEC renta.usp_Usuario_Registrar @nombre_completo='Cliente prueba flujo',@email='cliente.flujo@prueba.test',
  @password=N'RentaTicaFlujo2026!',@usuario_id=@cliente_id OUTPUT;
EXEC renta.usp_CategoriaEquipo_Crear @negocio_id=@negocio_id,@nombre='Equipo flujo API',
  @tarifa_hora=10,@tarifa_dia=40,@monto_deposito=0,@categoria_id=@categoria_id OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id=@negocio_id,@categoria_id=@categoria_id,
  @codigo_interno='FLUJO-001',@descripcion='Equipo temporal 1 para pruebas de reserva',@equipo_id=@equipo_id OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id=@negocio_id,@categoria_id=@categoria_id,
  @codigo_interno='FLUJO-002',@descripcion='Equipo temporal 2 para pruebas de reserva',@equipo_id=@equipo_id_2 OUTPUT;
EXEC renta.usp_Equipo_Crear @negocio_id=@negocio_id,@categoria_id=@categoria_id,
  @codigo_interno='FLUJO-003',@descripcion='Equipo temporal 3 para pruebas de reserva',@equipo_id=@equipo_id_3 OUTPUT;
SELECT @negocio_id AS negocio_id,@operador_id AS operador_id,@cliente_id AS cliente_id,
       @categoria_id AS categoria_id,@equipo_id AS equipo_flujo_001_id,
       @equipo_id_2 AS equipo_flujo_002_id,@equipo_id_3 AS equipo_flujo_003_id,
       'operador.flujo@prueba.test' AS correo_operador,'RentaTicaFlujo2026!' AS contrasena_temporal;
EXEC renta.usp_MetodoPago_Listar;
GO
