/* Tabla renta.Usuario. Ejecutar en el orden numerado de esta carpeta. */
USE RentaTicaDB;
GO

CREATE TABLE renta.Usuario (
    usuario_id          INT IDENTITY(1,1) PRIMARY KEY,
    nombre_completo      VARCHAR(100) NOT NULL,
    email                VARCHAR(100) NOT NULL,
    password_hash        VARCHAR(256) NOT NULL,
    telefono             VARCHAR(20)  NULL,
    documento_identidad  VARCHAR(30)  NULL,
    rol_id               INT NOT NULL,
    negocio_id           INT NULL,
    fecha_creacion       DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_Usuario_email      UNIQUE (email),
    CONSTRAINT FK_Usuario_Rol        FOREIGN KEY (rol_id) REFERENCES renta.Rol(rol_id),
    CONSTRAINT FK_Usuario_Negocio    FOREIGN KEY (negocio_id) REFERENCES renta.Negocio(negocio_id)
);
GO

