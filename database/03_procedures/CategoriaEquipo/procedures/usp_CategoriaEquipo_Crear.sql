USE RentaTicaDB;
GO

/* ############################################################################
   CATEGORIA EQUIPO
   ############################################################################ */

CREATE OR ALTER PROCEDURE renta.usp_CategoriaEquipo_Crear
    @negocio_id     INT,
    @nombre         VARCHAR(80),
    @descripcion    VARCHAR(300) = NULL,
    @tarifa_hora    DECIMAL(10,2),
    @tarifa_dia     DECIMAL(10,2),
    @monto_deposito DECIMAL(10,2),
    @categoria_id   INT OUTPUT
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_CategoriaEquipo_Crear
   Descripcion: Crea una categoria de equipo con sus tarifas y deposito.
   Parametros:  datos de la categoria (entrada), @categoria_id (salida)
   Errores:     50003 datos invalidos; 50001 negocio inexistente; 50004 negocio
                suspendido; 50002 nombre repetido en el negocio
   Autor:       <integrante>        Fecha: 2026-10-19
---------------------------------------------------------------------------- */
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
            THROW 50003, 'El nombre de la categoria es obligatorio.', 1;
        IF @tarifa_hora IS NULL OR @tarifa_hora <= 0
            THROW 50003, 'La tarifa por hora debe ser mayor que cero.', 1;
        IF @tarifa_dia IS NULL OR @tarifa_dia <= 0
            THROW 50003, 'La tarifa por dia debe ser mayor que cero.', 1;
        IF @tarifa_dia < @tarifa_hora
            THROW 50003, 'La tarifa por dia no puede ser menor que la tarifa por hora.', 1;
        IF @monto_deposito IS NULL OR @monto_deposito < 0
            THROW 50003, 'El monto del deposito no puede ser negativo.', 1;

        IF NOT EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id)
            THROW 50001, 'El negocio no existe.', 1;
        IF EXISTS (SELECT 1 FROM renta.Negocio WHERE negocio_id = @negocio_id AND estado = 'Suspendido')
            THROW 50004, 'El negocio esta suspendido.', 1;
        IF EXISTS (SELECT 1 FROM renta.CategoriaEquipo
                   WHERE negocio_id = @negocio_id AND nombre = LTRIM(RTRIM(@nombre)))
            THROW 50002, 'Ya existe una categoria con ese nombre en el negocio.', 1;

        INSERT INTO renta.CategoriaEquipo (negocio_id, nombre, descripcion, tarifa_hora, tarifa_dia, monto_deposito)
        VALUES (@negocio_id, LTRIM(RTRIM(@nombre)), @descripcion, @tarifa_hora, @tarifa_dia, @monto_deposito);

        SET @categoria_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
