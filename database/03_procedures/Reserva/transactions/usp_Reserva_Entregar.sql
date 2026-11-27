USE RentaTicaDB;
GO
/* Entrega completa de una anticipada. Pagos y deposito son independientes.
   Los IDs de equipos se leen de la reserva, nunca del cliente HTTP. */
CREATE OR ALTER PROCEDURE renta.usp_Reserva_Entregar
    @reserva_id INT, @negocio_id INT, @usuario_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @estado VARCHAR(20), @tipo VARCHAR(20), @inicio DATETIME, @fin DATETIME,
                @total DECIMAL(10,2), @pagado DECIMAL(38,2), @ahora DATETIME;
        SELECT @estado=estado,@tipo=tipo_reserva,@inicio=fecha_inicio,@fin=fecha_fin,@total=monto_final
        FROM renta.Reserva WITH(UPDLOCK,HOLDLOCK)
        WHERE reserva_id=@reserva_id AND negocio_id=@negocio_id;
        IF @estado IS NULL THROW 50001,'La reserva no existe en este negocio.',1;
        IF NOT EXISTS(SELECT 1 FROM renta.Usuario u JOIN renta.Rol r ON r.rol_id=u.rol_id
            WHERE u.usuario_id=@usuario_id AND u.negocio_id=@negocio_id AND r.nombre IN ('Administrador','Operador'))
            THROW 50004,'El usuario no puede entregar equipos de este negocio.',1;
        IF NOT EXISTS(SELECT 1 FROM renta.Negocio WHERE negocio_id=@negocio_id AND estado='Activo')
            THROW 50004,'El negocio no esta activo.',1;
        IF @tipo<>'Anticipada' OR @estado<>'Confirmada'
            THROW 50004,'La entrega requiere una reserva anticipada Confirmada.',1;
        SELECT @pagado=ISNULL(SUM(monto),0) FROM renta.Pago WITH(HOLDLOCK)
        WHERE reserva_id=@reserva_id AND estado='Completado';
        IF @total-@pagado<>0 THROW 50004,'Debe completar el pago del alquiler antes de entregar. La garantia no cuenta como abono.',1;

        DECLARE @detalles TABLE(detalle_id INT PRIMARY KEY,equipo_id INT,
            entrega DATETIME,devolucion DATETIME);
        INSERT INTO @detalles
        SELECT detalle_id,equipo_id,fecha_hora_entrega,fecha_hora_devolucion
        FROM renta.DetalleReserva WITH(UPDLOCK,HOLDLOCK) WHERE reserva_id=@reserva_id;
        IF NOT EXISTS(SELECT 1 FROM @detalles)
            THROW 50004,'La reserva no tiene equipos asignados.',1;
        IF EXISTS(SELECT 1 FROM @detalles WHERE entrega IS NOT NULL OR devolucion IS NOT NULL)
            THROW 50004,'La reserva contiene equipos ya entregados o devueltos.',1;
        DECLARE @equipos TABLE(equipo_id INT PRIMARY KEY,estado VARCHAR(20),negocio_id INT);
        INSERT INTO @equipos
        SELECT e.equipo_id,e.estado,c.negocio_id
        FROM renta.Equipo e WITH(UPDLOCK,HOLDLOCK)
        JOIN renta.CategoriaEquipo c WITH(HOLDLOCK) ON c.categoria_id=e.categoria_id
        WHERE e.equipo_id IN (SELECT equipo_id FROM @detalles);
        IF (SELECT COUNT(*) FROM @equipos)<>(SELECT COUNT(*) FROM @detalles)
           OR EXISTS(SELECT 1 FROM @equipos WHERE negocio_id<>@negocio_id)
            THROW 50004,'La asignacion de equipos de la reserva no es valida para este negocio.',1;
        IF EXISTS(SELECT 1 FROM @equipos WHERE estado NOT IN ('Disponible','Reservado'))
            THROW 50004,'Uno o mas equipos no estan en condiciones de salir.',1;
        IF EXISTS(SELECT 1 FROM renta.Mantenimiento m WITH(HOLDLOCK)
            JOIN @equipos e ON e.equipo_id=m.equipo_id WHERE m.fecha_fin IS NULL)
            THROW 50004,'Uno o mas equipos tienen mantenimiento abierto.',1;
        IF EXISTS(SELECT 1 FROM renta.DetalleReserva d WITH(HOLDLOCK)
            JOIN @equipos e ON e.equipo_id=d.equipo_id
            WHERE d.reserva_id<>@reserva_id AND d.fecha_hora_entrega IS NOT NULL AND d.fecha_hora_devolucion IS NULL)
            THROW 50004,'Un equipo sigue pendiente de devolucion en otro alquiler.',1;
        -- Read SQL time after acquiring locks: a wait must not extend the allowed window.
        SET @ahora=GETDATE();
        IF @ahora<@inicio OR @ahora>=@fin
            THROW 50004,'La entrega se permite desde el inicio previsto y antes del fin de la reserva.',1;
        UPDATE d SET fecha_hora_entrega=@ahora
        FROM renta.DetalleReserva d JOIN @detalles x ON x.detalle_id=d.detalle_id
        WHERE d.reserva_id=@reserva_id;
        EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=@usuario_id;
        UPDATE e SET estado='Alquilado' FROM renta.Equipo e JOIN @equipos x ON x.equipo_id=e.equipo_id;
        UPDATE renta.Reserva SET estado='En curso' WHERE reserva_id=@reserva_id AND negocio_id=@negocio_id;
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
