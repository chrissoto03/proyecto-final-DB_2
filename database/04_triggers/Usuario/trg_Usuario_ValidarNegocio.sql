USE RentaTicaDB;
GO

/* Nombre: trg_Usuario_ValidarNegocio
   Descripcion: Aplica la regla de pertenencia a negocio segun el rol.
   Evento: INSERT, UPDATE de Usuario. Autor: equipo RentaTica. Fecha: 2026-10-19 */
CREATE OR ALTER TRIGGER renta.trg_Usuario_ValidarNegocio
ON renta.Usuario
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN renta.Rol r ON r.rol_id=i.rol_id
        WHERE (r.nombre='Cliente' AND i.negocio_id IS NOT NULL)
           OR (r.nombre<>'Cliente' AND i.negocio_id IS NULL)
    )
    BEGIN
        THROW 50003, 'Cliente debe tener negocio NULL; Administrador y Operador requieren negocio.', 1;
    END
END
GO
