USE RentaTicaDB;
GO

/* ----------------------------------------------------------------------------
   fn_VerificarPassword
   Descripcion: 1 si la contrasena coincide con el valor guardado 'salt:hash',
                0 en cualquier otro caso.
   Parametros:  @password (texto plano), @almacenado (valor de Usuario.password_hash)
   Autor: <integrante>     Fecha: 2026-10-19
---------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION renta.fn_VerificarPassword
(
    @password   NVARCHAR(100),
    @almacenado VARCHAR(256)
)
RETURNS BIT
AS
BEGIN
    DECLARE @pos INT = CHARINDEX(':', @almacenado);
    IF @pos IS NULL OR @pos = 0
        RETURN 0;

    DECLARE @salt VARCHAR(32) = LEFT(@almacenado, @pos - 1);

    IF renta.fn_HashPassword(@password, @salt) = @almacenado
        RETURN 1;

    RETURN 0;
END
GO
