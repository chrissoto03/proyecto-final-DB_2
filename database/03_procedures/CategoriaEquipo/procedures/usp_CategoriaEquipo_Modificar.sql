USE RentaTicaDB;
GO

CREATE OR ALTER PROCEDURE renta.usp_CategoriaEquipo_Modificar
    @categoria_id   INT,
    @negocio_id     INT,
    @nombre         VARCHAR(80),
    @descripcion    VARCHAR(300) = NULL,
    @tarifa_hora    DECIMAL(10,2),
    @tarifa_dia     DECIMAL(10,2),
    @monto_deposito DECIMAL(10,2)
AS
/* ----------------------------------------------------------------------------
   Nombre:      usp_CategoriaEquipo_Modificar
   Descripcion: Actualiza nombre, descripcion y tarifas. Las reservas ya hechas
                conservan su monto (tarifa_aplicada es una copia del momento).
   Parametros:  @categoria_id, @negocio_id y los datos nuevos
   Errores:     50003 datos invalidos; 50001 no existe en el negocio;
                50002 nombre repetido
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

        IF NOT EXISTS (SELECT 1 FROM renta.CategoriaEquipo
                       WHERE categoria_id = @categoria_id AND negocio_id = @negocio_id)
            THROW 50001, 'La categoria no existe en este negocio.', 1;
        IF EXISTS (SELECT 1 FROM renta.CategoriaEquipo
                   WHERE negocio_id = @negocio_id AND nombre = LTRIM(RTRIM(@nombre))
                     AND categoria_id <> @categoria_id)
            THROW 50002, 'Ya existe otra categoria con ese nombre en el negocio.', 1;

        UPDATE renta.CategoriaEquipo
        SET nombre = LTRIM(RTRIM(@nombre)), descripcion = @descripcion,
            tarifa_hora = @tarifa_hora, tarifa_dia = @tarifa_dia, monto_deposito = @monto_deposito
        WHERE categoria_id = @categoria_id;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
