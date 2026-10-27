USE RentaTicaDB;
GO

/* ----------------------------------------------------------------------------
   fn_HashPassword
   Descripcion: devuelve 'salt:hash', donde hash = SHA2-256 de (salt + password).
                El salt lo genera el SP que llama (una funcion no puede generar
                valores aleatorios), uno distinto por usuario.
   Parametros:  @password (texto plano), @salt (32 caracteres hexadecimales)
   Autor: <integrante>     Fecha: 2026-10-19
---------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION renta.fn_HashPassword
(
    @password NVARCHAR(100),
    @salt     VARCHAR(32)
)
RETURNS VARCHAR(256)
AS
BEGIN
    RETURN CONCAT(@salt, ':',
                  CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONCAT(@salt, @password)), 2));
END
GO
