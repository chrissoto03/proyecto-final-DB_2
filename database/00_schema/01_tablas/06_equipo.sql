/* Tabla renta.Equipo. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Equipo (
    equipo_id         INT IDENTITY(1,1) PRIMARY KEY,
    categoria_id      INT NOT NULL,
    codigo_interno    VARCHAR(20) NOT NULL,
    descripcion       VARCHAR(200) NULL,
    estado            VARCHAR(20) NOT NULL DEFAULT 'Disponible',
    notas             VARCHAR(300) NULL,
    fecha_adquisicion DATE NULL,
    CONSTRAINT UQ_Equipo_codigo   UNIQUE (categoria_id, codigo_interno),
    CONSTRAINT FK_Equipo_Categoria FOREIGN KEY (categoria_id) REFERENCES renta.CategoriaEquipo(categoria_id),
    CONSTRAINT CHK_Equipo_estado  CHECK (estado IN ('Disponible','Reservado','Alquilado','Mantenimiento','Averiado','Fuera de servicio'))
);
GO

