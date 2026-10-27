/* Tabla renta.MetodoPago. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.MetodoPago (
    metodo_pago_id INT IDENTITY(1,1) PRIMARY KEY,
    nombre         VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_MetodoPago_nombre  UNIQUE (nombre)
);
GO

