/* Tabla renta.Mantenimiento. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Mantenimiento (
    mantenimiento_id INT IDENTITY(1,1) PRIMARY KEY,
    equipo_id        INT NOT NULL,
    operador_id      INT NULL,
    tipo             VARCHAR(20) NOT NULL,
    descripcion      VARCHAR(300) NULL,
    costo            DECIMAL(10,2) NOT NULL DEFAULT 0,
    fecha_inicio     DATE NOT NULL,
    fecha_fin        DATE NULL,
    CONSTRAINT FK_Mantenimiento_Equipo  FOREIGN KEY (equipo_id) REFERENCES renta.Equipo(equipo_id),
    CONSTRAINT FK_Mantenimiento_Usuario FOREIGN KEY (operador_id) REFERENCES renta.Usuario(usuario_id),
    CONSTRAINT CHK_Mantenimiento_tipo   CHECK (tipo IN ('Preventivo','Correctivo')),
    CONSTRAINT CHK_Mantenimiento_costo  CHECK (costo >= 0)
);
GO

