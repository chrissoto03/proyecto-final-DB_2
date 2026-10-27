USE RentaTicaDB;
GO

/* ############################################################################
   MANTENIMIENTO
   Crear y Finalizar son transacciones explicitas: cambian dos tablas
   (Mantenimiento y Equipo) y deben quedar las dos o ninguna.
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_Mantenimiento_Crear
    @negocio_id       INT,
    @equipo_id        INT,
    @operador_id      INT,
    @tipo             VARCHAR(20),
    @descripcion      VARCHAR(300) = NULL,
    @costo            DECIMAL(10,2) = 0,
    @fecha_inicio     DATE = NULL,
    @mantenimiento_id INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Mantenimiento_Crear
   Descripcion: TRANSACCION. Registra un mantenimiento y pasa el equipo a
                estado Mantenimiento. Solo procede si el equipo esta
                Disponible o Averiado (no si esta reservado o alquilado).
                Bloquea la fila del equipo (UPDLOCK) para que dos operadores
                no lo manden a mantenimiento a la vez.
   Parametros:  @negocio_id, @equipo_id, @operador_id (quien registra), @tipo
                ('Preventivo'/'Correctivo'), @descripcion, @costo,
                @fecha_inicio (NULL = hoy), @mantenimiento_id (salida)
   Errores:     50003 datos invalidos; 50001 equipo u operador inexistente en
                el negocio; 50004 estado del equipo no permite mantenimiento
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @tipo IS NULL OR @tipo NOT IN ('Preventivo', 'Correctivo')
            THROW 50003, 'El tipo debe ser Preventivo o Correctivo.', 1;
        IF @costo IS NULL OR @costo < 0
            THROW 50003, 'El costo no puede ser negativo.', 1;
        IF NOT EXISTS (SELECT 1 FROM renta.Usuario WHERE usuario_id = @operador_id AND negocio_id = @negocio_id)
            THROW 50001, 'El operador no pertenece a este negocio.', 1;

        SET @fecha_inicio = ISNULL(@fecha_inicio, CAST(GETDATE() AS DATE));

        BEGIN TRANSACTION;

        DECLARE @estado_actual VARCHAR(20);

        SELECT @estado_actual = e.estado
        FROM renta.Equipo e WITH (UPDLOCK, ROWLOCK)
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE e.equipo_id = @equipo_id AND c.negocio_id = @negocio_id;

        IF @estado_actual IS NULL
            THROW 50001, 'El equipo no existe en este negocio.', 1;
        IF @estado_actual NOT IN ('Disponible', 'Averiado')
            THROW 50004, 'Solo se puede enviar a mantenimiento un equipo Disponible o Averiado.', 1;

        INSERT INTO renta.Mantenimiento (equipo_id, operador_id, tipo, descripcion, costo, fecha_inicio)
        VALUES (@equipo_id, @operador_id, @tipo, @descripcion, @costo, @fecha_inicio);

        SET @mantenimiento_id = SCOPE_IDENTITY();

        EXEC sp_set_session_context @key = N'usuario_actual', @value = @operador_id;

        UPDATE renta.Equipo SET estado = 'Mantenimiento' WHERE equipo_id = @equipo_id;
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
