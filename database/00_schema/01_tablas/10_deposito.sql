/* Tabla renta.Deposito. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Deposito (
    deposito_id      INT IDENTITY(1,1) PRIMARY KEY,
    reserva_id       INT NOT NULL,
    monto_cobrado    DECIMAL(10,2) NOT NULL,
    monto_devuelto   DECIMAL(10,2) NULL,
    monto_retencion  DECIMAL(10,2) NULL,
    fecha_devolucion DATETIME NULL,
    CONSTRAINT UQ_Deposito_Reserva  UNIQUE (reserva_id),
    CONSTRAINT FK_Deposito_Reserva  FOREIGN KEY (reserva_id) REFERENCES renta.Reserva(reserva_id),
    CONSTRAINT CHK_Deposito_cobrado CHECK (monto_cobrado >= 0),
    CONSTRAINT CHK_Deposito_cuadre  CHECK (
        monto_devuelto IS NULL
        OR monto_retencion IS NULL
        OR monto_cobrado = monto_devuelto + monto_retencion
    )
);
GO

