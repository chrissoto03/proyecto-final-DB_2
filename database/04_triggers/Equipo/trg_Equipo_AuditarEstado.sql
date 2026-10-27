USE RentaTicaDB;
GO

/* Nombre: trg_Equipo_AuditarEstado
   Descripcion: Registra cada cambio real de estado de equipo y el usuario actual.
   Evento: UPDATE de Equipo.estado. Autor: equipo RentaTica. Fecha: 2026-10-19 */
CREATE OR ALTER TRIGGER renta.trg_Equipo_AuditarEstado
ON renta.Equipo
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(estado)
    BEGIN
        INSERT INTO renta.AuditoriaEquipo(equipo_id,usuario_id,estado_anterior,estado_nuevo)
        SELECT i.equipo_id,TRY_CONVERT(INT,SESSION_CONTEXT(N'usuario_actual')),d.estado,i.estado
        FROM inserted i
        JOIN deleted d ON d.equipo_id=i.equipo_id
        WHERE i.estado<>d.estado;
    END
END
GO
