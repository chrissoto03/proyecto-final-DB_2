/* Tabla renta.Pago. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Pago (
    pago_id        INT IDENTITY(1,1) PRIMARY KEY,
    reserva_id     INT NOT NULL,
    metodo_pago_id INT NOT NULL,
    monto          DECIMAL(10,2) NOT NULL,
    fecha_pago     DATETIME NOT NULL DEFAULT GETDATE(),
    estado         VARCHAR(20) NOT NULL DEFAULT 'Completado',
    CONSTRAINT FK_Pago_Reserva     FOREIGN KEY (reserva_id) REFERENCES renta.Reserva(reserva_id),
    CONSTRAINT FK_Pago_MetodoPago  FOREIGN KEY (metodo_pago_id) REFERENCES renta.MetodoPago(metodo_pago_id),
    CONSTRAINT CHK_Pago_monto      CHECK (monto > 0),
    CONSTRAINT CHK_Pago_estado     CHECK (estado IN ('Completado','Reembolsado'))
);
GO

