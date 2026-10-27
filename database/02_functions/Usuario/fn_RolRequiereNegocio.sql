USE RentaTicaDB;
GO

/* ----------------------------------------------------------------------------
   fn_RolRequiereNegocio
   Descripcion: regla de negocio de la multi-tenencia. Administrador, Operador y
                cualquier rol de personal pertenecen a un negocio; el Cliente
                no (puede alquilar en cualquier negocio de la plataforma).
   Retorna:     1 si el rol exige negocio_id, 0 si no (o si el rol no existe)
   Autor: <integrante>     Fecha: 2026-10-19
---------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION renta.fn_RolRequiereNegocio
(
    @rol_id INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @requiere BIT = 0;

    IF EXISTS (SELECT 1 FROM renta.Rol WHERE rol_id = @rol_id AND nombre <> 'Cliente')
        SET @requiere = 1;

    RETURN @requiere;
END
GO
