/* Tabla renta.Reserva. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Reserva (
    reserva_id    INT IDENTITY(1,1) PRIMARY KEY,
    negocio_id    INT NOT NULL,
    cliente_id    INT NOT NULL,
    operador_id   INT NULL,
    tipo_reserva  VARCHAR(20) NOT NULL,
    fecha_reserva DATETIME NOT NULL DEFAULT GETDATE(),
    fecha_inicio  DATETIME NOT NULL,
    fecha_fin     DATETIME NOT NULL,
    estado        VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
    monto_final   DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_Reserva_Negocio  FOREIGN KEY (negocio_id) REFERENCES renta.Negocio(negocio_id),
    CONSTRAINT FK_Reserva_Cliente  FOREIGN KEY (cliente_id) REFERENCES renta.Usuario(usuario_id),
    CONSTRAINT FK_Reserva_Operador FOREIGN KEY (operador_id) REFERENCES renta.Usuario(usuario_id),
    CONSTRAINT CHK_Reserva_tipo    CHECK (tipo_reserva IN ('Anticipada','Walk-in')),
    CONSTRAINT CHK_Reserva_estado  CHECK (estado IN ('Pendiente','Confirmada','En curso','Completada','Cancelada')),
    CONSTRAINT CHK_Reserva_monto   CHECK (monto_final >= 0),
    CONSTRAINT CHK_Reserva_fechas  CHECK (fecha_fin >= fecha_inicio)
);
GO

