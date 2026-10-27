USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_Equipo_ActualizarEstado
    @equipo_id    INT,
    @negocio_id   INT,
    @nuevo_estado VARCHAR(20),
    @usuario_id   INT = NULL
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_Equipo_ActualizarEstado
   Descripcion: Cambia el estado de un equipo entre Disponible, Averiado y
                Fuera de servicio. Reservado, Alquilado y Mantenimiento los
                asigna el propio sistema, por lo que no se pueden poner ni
                quitar a mano. Deja en la sesion quien hizo el cambio para
                que el trigger de auditoria (script 10) lo registre.
   Parametros:  @equipo_id, @negocio_id, @nuevo_estado, @usuario_id (quien cambia)
   Errores:     50001 no existe en el negocio; 50003 estado no permitido;
                50004 el equipo esta Reservado/Alquilado/Mantenimiento o ya
                tiene ese estado
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @estado_actual VARCHAR(20);

        SELECT @estado_actual = e.estado
        FROM renta.Equipo e
        INNER JOIN renta.CategoriaEquipo c ON c.categoria_id = e.categoria_id
        WHERE e.equipo_id = @equipo_id AND c.negocio_id = @negocio_id;

        IF @estado_actual IS NULL
            THROW 50001, 'El equipo no existe en este negocio.', 1;

        IF @nuevo_estado IS NULL OR @nuevo_estado NOT IN ('Disponible', 'Averiado', 'Fuera de servicio')
            THROW 50003, 'Estado no permitido. Use Disponible, Averiado o Fuera de servicio.', 1;

        IF @estado_actual IN ('Reservado', 'Alquilado', 'Mantenimiento')
            THROW 50004, 'El equipo esta reservado, alquilado o en mantenimiento; ese estado lo gestiona el sistema.', 1;

        IF @estado_actual = @nuevo_estado
            THROW 50004, 'El equipo ya tiene ese estado.', 1;

        EXEC sp_set_session_context @key = N'usuario_actual', @value = @usuario_id;

        UPDATE renta.Equipo SET estado = @nuevo_estado WHERE equipo_id = @equipo_id;
        EXEC sys.sp_set_session_context @key = N'usuario_actual', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'usuario_actual', @value = NULL;
        THROW;
    END CATCH
END
GO
