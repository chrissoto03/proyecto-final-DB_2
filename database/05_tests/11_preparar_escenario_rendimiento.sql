/*
  R4 - Escenario temporal para capturar planes de consulta.
  Crea un negocio aislado con 250 equipos, 40 reservas futuras y 40 pagos.
  No elimina ni modifica datos de otros negocios.
  Re-ejecutable: primero elimina solo el negocio identificado como R4 benchmark.
  Ejecute en una base local de pruebas con esquema, SPs y catálogo instalados.
*/
USE RentaTicaDB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/* Limpieza idempotente del escenario anterior con este identificador exclusivo. */
DECLARE @old_negocio_id INT = (SELECT negocio_id FROM renta.Negocio WHERE email_contacto='r4-benchmark@prueba.test');
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
    DELETE FROM renta.Usuario WHERE negocio_id=@old_negocio_id OR email='r4-benchmark-cliente@prueba.test';
    DELETE FROM renta.Negocio WHERE negocio_id=@old_negocio_id;
END;
IF EXISTS (SELECT 1 FROM renta.Usuario WHERE email IN ('r4-benchmark-operador@prueba.test','r4-benchmark-cliente@prueba.test'))
    THROW 51001, 'Ya existe un usuario del escenario R4 fuera del negocio esperado; revise antes de continuar.', 1;
IF NOT EXISTS (SELECT 1 FROM renta.MetodoPago WHERE nombre='Efectivo')
    THROW 51002, 'Falta el metodo de pago Efectivo. Ejecute primero el seed de catalogos.', 1;
GO

DECLARE @negocio_id INT, @operador_id INT, @cliente_id INT, @categoria_id INT;
DECLARE @equipo_id INT, @reserva_id INT, @pago_id INT, @metodo_pago_id INT;
DECLARE @i INT=1, @codigo VARCHAR(20), @fecha_inicio DATETIME, @fecha_fin DATETIME;
DECLARE @equipos_json NVARCHAR(100), @monto DECIMAL(10,2);
DECLARE @equipos TABLE (numero INT PRIMARY KEY, equipo_id INT NOT NULL);
SET @metodo_pago_id=(SELECT metodo_pago_id FROM renta.MetodoPago WHERE nombre='Efectivo');

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC renta.usp_Negocio_Crear @nombre='Escenario de rendimiento R4',
      @email_contacto='r4-benchmark@prueba.test', @negocio_id=@negocio_id OUTPUT;
    EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo='Operador benchmark R4',
      @email='r4-benchmark-operador@prueba.test', @password=N'R4Benchmark2026!',
      @rol_nombre='Operador', @negocio_id=@negocio_id, @usuario_id=@operador_id OUTPUT;
    EXEC renta.usp_Usuario_Registrar @nombre_completo='Cliente benchmark R4',
      @email='r4-benchmark-cliente@prueba.test', @password=N'R4Benchmark2026!',
      @usuario_id=@cliente_id OUTPUT;
    EXEC renta.usp_CategoriaEquipo_Crear @negocio_id=@negocio_id, @nombre='Equipo R4 benchmark',
      @tarifa_hora=10, @tarifa_dia=50, @monto_deposito=0, @categoria_id=@categoria_id OUTPUT;

    /* Crear los equipos por el procedimiento de negocio para respetar sus validaciones. */
    WHILE @i <= 250
    BEGIN
        SET @codigo='R4-' + RIGHT('0000' + CONVERT(VARCHAR(4),@i),4);
        EXEC renta.usp_Equipo_Crear @negocio_id=@negocio_id, @categoria_id=@categoria_id,
          @codigo_interno=@codigo, @descripcion='Equipo temporal de rendimiento R4', @equipo_id=@equipo_id OUTPUT;
        INSERT INTO @equipos(numero,equipo_id) VALUES(@i,@equipo_id);
        SET @i+=1;
    END;

    /* 40 reservas futuras de dos horas, cada una con equipo distinto; el pago completo
       confirma la reserva y alimenta el reporte de ingresos de los últimos 90 días. */
    SET @i=1;
    WHILE @i <= 40
    BEGIN
        SELECT @equipo_id=equipo_id FROM @equipos WHERE numero=@i;
        SET @equipos_json=N'[' + CONVERT(NVARCHAR(12),@equipo_id) + N']';
        SET @fecha_inicio=DATEADD(DAY,1+((@i-1)%28),CONVERT(DATETIME,CONVERT(DATE,GETDATE())));
        SET @fecha_fin=DATEADD(HOUR,2,@fecha_inicio);
        EXEC renta.usp_Reserva_Crear @negocio_id=@negocio_id, @cliente_id=@cliente_id,
          @operador_id=@operador_id, @tipo_reserva='Anticipada', @fecha_inicio=@fecha_inicio,
          @fecha_fin=@fecha_fin, @equipos_json=@equipos_json, @reserva_id=@reserva_id OUTPUT;
        SELECT @monto=monto_final FROM renta.Reserva WHERE reserva_id=@reserva_id;
        EXEC renta.usp_Pago_Registrar @reserva_id=@reserva_id, @negocio_id=@negocio_id,
          @metodo_pago_id=@metodo_pago_id, @monto=@monto, @pago_id=@pago_id OUTPUT;
        SET @i+=1;
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT n.negocio_id, n.nombre, n.email_contacto,
       (SELECT COUNT(*) FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=n.negocio_id) AS equipos,
       (SELECT COUNT(*) FROM renta.Reserva r WHERE r.negocio_id=n.negocio_id) AS reservas,
       (SELECT COUNT(*) FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id WHERE r.negocio_id=n.negocio_id AND p.estado='Completado') AS pagos_completados
FROM renta.Negocio n WHERE n.negocio_id=@negocio_id;
GO
