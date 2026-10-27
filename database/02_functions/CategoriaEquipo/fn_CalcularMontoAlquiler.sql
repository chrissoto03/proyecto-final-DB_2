USE RentaTicaDB;
GO

/* ----------------------------------------------------------------------------
   fn_CalcularMontoAlquiler
   Descripcion: costo de alquilar un equipo entre dos momentos.
                Regla: se cobra por hora iniciada (se redondea hacia arriba);
                cada 24 horas completas se cobran como un dia; las horas
                restantes se cobran por hora pero nunca mas que una tarifa diaria.
   Parametros:  @tarifa_hora, @tarifa_dia, @fecha_inicio, @fecha_fin
   Retorna:     monto en DECIMAL(10,2); 0 si el rango es invalido
   Ejemplos (hora=15, dia=50): 2 h = 30 | 4 h = 50 | 24 h = 50 | 26 h = 80
   Autor: <integrante>     Fecha: 2026-10-19
---------------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION renta.fn_CalcularMontoAlquiler
(
    @tarifa_hora  DECIMAL(10,2),
    @tarifa_dia   DECIMAL(10,2),
    @fecha_inicio DATETIME,
    @fecha_fin    DATETIME
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @minutos INT = DATEDIFF(MINUTE, @fecha_inicio, @fecha_fin);

    IF @minutos IS NULL OR @minutos <= 0
        RETURN 0;

    DECLARE @horas       INT = CEILING(@minutos / 60.0);
    DECLARE @dias        INT = @horas / 24;
    DECLARE @horas_resto INT = @horas % 24;
    DECLARE @costo_resto DECIMAL(10,2) = @horas_resto * @tarifa_hora;

    IF @costo_resto > @tarifa_dia
        SET @costo_resto = @tarifa_dia;

    RETURN (@dias * @tarifa_dia) + @costo_resto;
END
GO
