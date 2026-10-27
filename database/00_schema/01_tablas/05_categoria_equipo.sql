/* Tabla renta.CategoriaEquipo. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.CategoriaEquipo (
    categoria_id   INT IDENTITY(1,1) PRIMARY KEY,
    negocio_id     INT NOT NULL,
    nombre         VARCHAR(80) NOT NULL,
    descripcion    VARCHAR(300) NULL,
    tarifa_hora    DECIMAL(10,2) NOT NULL,
    tarifa_dia     DECIMAL(10,2) NOT NULL,
    monto_deposito DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_CategoriaEquipo_Negocio   FOREIGN KEY (negocio_id) REFERENCES renta.Negocio(negocio_id),
    CONSTRAINT CHK_CategoriaEquipo_tarifah  CHECK (tarifa_hora > 0),
    CONSTRAINT CHK_CategoriaEquipo_tarifad  CHECK (tarifa_dia > 0),
    CONSTRAINT CHK_CategoriaEquipo_deposito CHECK (monto_deposito >= 0)
);
GO

