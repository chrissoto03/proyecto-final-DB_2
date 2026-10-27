/* Tabla renta.Rol. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Rol (
    rol_id   INT IDENTITY(1,1) PRIMARY KEY,
    nombre   VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_Rol_nombre   UNIQUE (nombre)
);
GO

