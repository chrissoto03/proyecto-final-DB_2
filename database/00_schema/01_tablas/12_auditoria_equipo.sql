/* Tabla renta.AuditoriaEquipo. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.AuditoriaEquipo (
    auditoria_id    INT IDENTITY(1,1) PRIMARY KEY,
    equipo_id       INT NOT NULL,
    usuario_id      INT NULL,
    estado_anterior VARCHAR(20) NULL,
    estado_nuevo    VARCHAR(20) NOT NULL,
    fecha_hora      DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_AuditoriaEquipo_Equipo   FOREIGN KEY (equipo_id) REFERENCES renta.Equipo(equipo_id),
    CONSTRAINT FK_AuditoriaEquipo_Usuario  FOREIGN KEY (usuario_id) REFERENCES renta.Usuario(usuario_id)
);
GO

