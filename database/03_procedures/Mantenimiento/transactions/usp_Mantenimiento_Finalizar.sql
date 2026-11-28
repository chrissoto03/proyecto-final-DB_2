USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Mantenimiento_Finalizar
    @mantenimiento_id INT,
    @negocio_id       INT,
    @fecha_fin        DATE = NULL,
    @costo            DECIMAL(10,2) = NULL,
    @estado_equipo    VARCHAR(20) = 'Disponible',
    @usuario_id       INT = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Mantenimiento_Finalizar
   Descripcion: TRANSACCION. Cierra un mantenimiento abierto (fecha_fin, costo
                final opcional) y deja el equipo en el estado indicado.
   Parametros:  @mantenimiento_id, @negocio_id, @fecha_fin (NULL = hoy),
                @costo (NULL = conserva el actual), @estado_equipo
                ('Disponible', 'Averiado' o 'Fuera de servicio'), @usuario_id
   Errores:     50003 datos invalidos; 50001 no existe en el negocio;
                50004 el mantenimiento ya estaba finalizado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
        IF @estado_equipo IS NULL OR @estado_equipo NOT IN ('Disponible', 'Averiado', 'Fuera de servicio')
            THROW 50003, 'El equipo debe quedar Disponible, Averiado o Fuera de servicio.', 1;
        IF @costo IS NOT NULL AND @costo < 0
            THROW 50003, 'El costo no puede ser negativo.', 1;

        IF NOT EXISTS(SELECT 1 FROM renta.Usuario u JOIN renta.Rol r ON r.rol_id=u.rol_id
            JOIN renta.Negocio n ON n.negocio_id=u.negocio_id
            WHERE u.usuario_id=@usuario_id AND u.negocio_id=@negocio_id AND r.nombre IN ('Administrador','Operador') AND n.estado='Activo')
            THROW 50004,'El usuario no puede finalizar mantenimientos de este negocio.',1;
        BEGIN TRANSACTION;
        -- Same lock order as creation: equipment, then maintenance.
        DECLARE @equipo_bloqueado INT;
        SELECT @equipo_bloqueado=e.equipo_id FROM renta.Equipo e WITH(UPDLOCK,HOLDLOCK)
        JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id
        WHERE c.negocio_id=@negocio_id AND e.equipo_id=(SELECT equipo_id FROM renta.Mantenimiento WHERE mantenimiento_id=@mantenimiento_id);
        IF @equipo_bloqueado IS NULL THROW 50001,'El mantenimiento no existe en este negocio.',1;

        DECLARE @equipo_id INT, @fecha_inicio DATE, @fecha_fin_actual DATE;

        SELECT @equipo_id = m.equipo_id, @fecha_inicio = m.fecha_inicio, @fecha_fin_actual = m.fecha_fin
        FROM renta.Mantenimiento m WITH (UPDLOCK, ROWLOCK)
        INNER JOIN renta.Equipo e ON e.equipo_id = m.equipo_id
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE m.mantenimiento_id = @mantenimiento_id AND c.negocio_id = @negocio_id;

        IF @equipo_id IS NULL
            THROW 50001, 'El mantenimiento no existe en este negocio.', 1;
        IF @fecha_fin_actual IS NOT NULL
            THROW 50004, 'El mantenimiento ya fue finalizado.', 1;

        SET @fecha_fin = ISNULL(@fecha_fin, CAST(GETDATE() AS DATE));
        IF @fecha_fin < @fecha_inicio
            THROW 50003, 'La fecha de fin no puede ser anterior a la de inicio.', 1;

        IF EXISTS(SELECT 1 FROM renta.Mantenimiento WITH(HOLDLOCK) WHERE equipo_id=@equipo_id AND mantenimiento_id<>@mantenimiento_id AND fecha_fin IS NULL)
            THROW 50004,'Existe otro mantenimiento abierto para este equipo.',1;
        IF EXISTS(SELECT 1 FROM renta.DetalleReserva WITH(HOLDLOCK) WHERE equipo_id=@equipo_id AND fecha_hora_entrega IS NOT NULL AND fecha_hora_devolucion IS NULL)
            THROW 50004,'El equipo sigue pendiente de devolucion en un alquiler.',1;
        IF @estado_equipo='Disponible' AND EXISTS(
            SELECT 1 FROM renta.DetalleReserva d WITH(HOLDLOCK) JOIN renta.Reserva r WITH(HOLDLOCK) ON r.reserva_id=d.reserva_id
            WHERE d.equipo_id=@equipo_id AND d.fecha_hora_devolucion IS NULL AND r.estado IN ('Pendiente','Confirmada','En curso'))
            SET @estado_equipo='Reservado';
        UPDATE renta.Mantenimiento
        SET fecha_fin = @fecha_fin, costo = ISNULL(@costo, costo)
        WHERE mantenimiento_id = @mantenimiento_id;

        EXEC sp_set_session_context @key = N'usuario_actual', @value = @usuario_id;

        UPDATE renta.Equipo SET estado = @estado_equipo WHERE equipo_id = @equipo_id;
        EXEC sys.sp_set_session_context @key = N'usuario_actual', @value = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'usuario_actual', @value = NULL;
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
