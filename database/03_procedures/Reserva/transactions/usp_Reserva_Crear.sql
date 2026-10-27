USE RentaTicaDB;
GO

/* Nombre: usp_Reserva_Crear
   Descripcion: Crea una reserva con uno o mas equipos disponibles y calcula
                el precio desde las tarifas vigentes. La operacion es atomica.
   Parametros: negocio, cliente, operador opcional, tipo, rango, equipos JSON,
               reserva_id OUTPUT.
   Autor: equipo RentaTica  Fecha: 2026-10-19 */
CREATE OR ALTER PROCEDURE renta.usp_Reserva_Crear
    @negocio_id INT, @cliente_id INT, @operador_id INT = NULL,
    @tipo_reserva VARCHAR(20), @fecha_inicio DATETIME, @fecha_fin DATETIME,
    @equipos_json NVARCHAR(MAX), @reserva_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF @tipo_reserva IS NULL OR @tipo_reserva NOT IN ('Anticipada','Walk-in') OR @fecha_inicio IS NULL
           OR @fecha_fin IS NULL OR @fecha_fin <= @fecha_inicio
           OR ISJSON(@equipos_json) <> 1 OR LEFT(LTRIM(@equipos_json),1) <> '['
            THROW 50003, 'Tipo, fechas o lista JSON de equipos invalida.', 1;
        IF @tipo_reserva='Walk-in' AND @fecha_inicio>GETDATE()
            THROW 50003, 'Una reserva Walk-in debe iniciar ahora o antes.', 1;
        IF @tipo_reserva='Walk-in' AND @operador_id IS NULL
            THROW 50003, 'Una reserva Walk-in requiere el operador que atiende.', 1;
        IF NOT EXISTS (SELECT 1 FROM renta.Usuario u JOIN renta.Rol r ON r.rol_id=u.rol_id
                       WHERE u.usuario_id=@cliente_id AND r.nombre='Cliente' AND u.negocio_id IS NULL)
            THROW 50003, 'El usuario indicado no es un cliente valido.', 1;
        IF @operador_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM renta.Usuario u JOIN renta.Rol r ON r.rol_id=u.rol_id
            WHERE u.usuario_id=@operador_id AND u.negocio_id=@negocio_id AND r.nombre='Operador')
            THROW 50001, 'El operador no pertenece al negocio.', 1;
        IF NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id=@negocio_id AND estado='Activo')
            THROW 50004, 'El negocio no existe o esta suspendido.', 1;

        DECLARE @equipos_json_ids TABLE(equipo_id INT NULL);
        INSERT INTO @equipos_json_ids(equipo_id)
        SELECT TRY_CONVERT(INT,[value]) FROM OPENJSON(@equipos_json);
        IF NOT EXISTS (SELECT 1 FROM @equipos_json_ids)
            THROW 50003, 'Debe incluir al menos un equipo.', 1;
        IF EXISTS (SELECT 1 FROM @equipos_json_ids WHERE equipo_id IS NULL OR equipo_id<=0)
            THROW 50003, 'La lista contiene un identificador de equipo invalido.', 1;
        IF EXISTS (SELECT equipo_id FROM @equipos_json_ids GROUP BY equipo_id HAVING COUNT(*)>1)
            THROW 50003, 'La lista contiene equipos duplicados.', 1;
        DECLARE @equipos TABLE(equipo_id INT PRIMARY KEY);
        INSERT INTO @equipos(equipo_id) SELECT equipo_id FROM @equipos_json_ids;

        BEGIN TRANSACTION;
        IF (SELECT COUNT(*) FROM renta.Equipo e WITH (UPDLOCK,HOLDLOCK)
            JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
            JOIN @equipos x ON x.equipo_id=e.equipo_id WHERE c.negocio_id=@negocio_id)
           <> (SELECT COUNT(*) FROM @equipos)
            THROW 50001, 'Uno o mas equipos no existen en el negocio.', 1;
        IF EXISTS (
            SELECT 1 FROM @equipos x JOIN renta.Equipo e ON e.equipo_id=x.equipo_id
            JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
            WHERE e.estado IN ('Averiado','Mantenimiento','Fuera de servicio')
               OR EXISTS (SELECT 1 FROM renta.DetalleReserva d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id
                          WHERE d.equipo_id=e.equipo_id AND d.fecha_hora_devolucion IS NULL
                            AND r.estado IN ('Pendiente','Confirmada','En curso')
                            AND r.fecha_inicio < @fecha_fin AND r.fecha_fin > @fecha_inicio))
            THROW 50004, 'Uno o mas equipos no estan disponibles en ese rango.', 1;

        DECLARE @estado VARCHAR(20)=CASE WHEN @tipo_reserva='Walk-in' THEN 'En curso' ELSE 'Pendiente' END;
        INSERT INTO renta.Reserva(negocio_id,cliente_id,operador_id,tipo_reserva,fecha_inicio,fecha_fin,estado,monto_final)
        VALUES(@negocio_id,@cliente_id,@operador_id,@tipo_reserva,@fecha_inicio,@fecha_fin,@estado,0);
        SET @reserva_id=CONVERT(INT,SCOPE_IDENTITY());
        INSERT INTO renta.DetalleReserva(reserva_id,equipo_id,tarifa_aplicada,fecha_hora_entrega)
        SELECT @reserva_id,e.equipo_id,
               renta.fn_CalcularMontoAlquiler(c.tarifa_hora,c.tarifa_dia,@fecha_inicio,@fecha_fin),
               CASE WHEN @tipo_reserva='Walk-in' THEN GETDATE() END
        FROM @equipos x JOIN renta.Equipo e ON e.equipo_id=x.equipo_id
        JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id;
        UPDATE r SET monto_final=(SELECT SUM(d.tarifa_aplicada) FROM renta.DetalleReserva d WHERE d.reserva_id=@reserva_id)
        FROM renta.Reserva r WHERE r.reserva_id=@reserva_id;
        EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=@operador_id;
        UPDATE e SET estado=CASE WHEN @tipo_reserva='Walk-in' THEN 'Alquilado' ELSE 'Reservado' END
        FROM renta.Equipo e JOIN @equipos x ON x.equipo_id=e.equipo_id;
        EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=NULL;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=NULL;
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
