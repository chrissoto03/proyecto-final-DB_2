/* Tabla renta.Negocio. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Negocio (
    negocio_id     INT IDENTITY(1,1) PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    direccion      VARCHAR(200) NULL,
    telefono       VARCHAR(20)  NULL,
    email_contacto VARCHAR(100) NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT GETDATE(),
    estado         VARCHAR(20) NOT NULL DEFAULT 'Activo',
    CONSTRAINT UQ_Negocio_email  UNIQUE (email_contacto),
    CONSTRAINT CHK_Negocio_estado CHECK (estado IN ('Activo','Suspendido'))
);
GO

