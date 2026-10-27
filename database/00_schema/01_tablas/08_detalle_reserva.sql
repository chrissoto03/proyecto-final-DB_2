/* Tabla renta.DetalleReserva. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.DetalleReserva (
    detalle_id              INT IDENTITY(1,1) PRIMARY KEY,
    reserva_id              INT NOT NULL,
    equipo_id               INT NOT NULL,
    tarifa_aplicada         DECIMAL(10,2) NOT NULL,
    fecha_hora_entrega      DATETIME NULL,
    fecha_hora_devolucion   DATETIME NULL,
    estado_equipo_devolucion VARCHAR(20) NULL,
    CONSTRAINT FK_DetalleReserva_Reserva FOREIGN KEY (reserva_id) REFERENCES renta.Reserva(reserva_id),
    CONSTRAINT FK_DetalleReserva_Equipo  FOREIGN KEY (equipo_id) REFERENCES renta.Equipo(equipo_id),
    CONSTRAINT CHK_DetalleReserva_tarifa CHECK (tarifa_aplicada >= 0),
    CONSTRAINT CHK_DetalleReserva_estado CHECK (estado_equipo_devolucion IS NULL OR estado_equipo_devolucion IN ('Bueno','Averiado','Perdido'))
);
GO

