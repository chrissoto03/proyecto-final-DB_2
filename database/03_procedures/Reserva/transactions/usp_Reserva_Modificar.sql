USE RentaTicaDB;
GO
/* Shared preview/commit calculation. Preview never writes. Confirmation binds to a
   fingerprint of the current reservation, payments and calculated proposal. */
CREATE OR ALTER PROCEDURE renta.usp_Reserva_Modificar
 @reserva_id INT,@negocio_id INT,@usuario_id INT,
 @fecha_inicio DATETIME,@fecha_fin DATETIME,@equipos_json NVARCHAR(MAX),
 @confirmar BIT=0,@version_esperada VARCHAR(64)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  IF @fecha_inicio IS NULL OR @fecha_fin IS NULL OR @fecha_fin<=@fecha_inicio
     OR ISJSON(@equipos_json)<>1 OR LEFT(LTRIM(@equipos_json),1)<>'['
   THROW 50003,'Indique fechas validas y una lista de equipos.',1;
  DECLARE @ids TABLE(id INT);
  INSERT @ids SELECT TRY_CONVERT(INT,value) FROM OPENJSON(@equipos_json);
  IF NOT EXISTS(SELECT 1 FROM @ids) OR (SELECT COUNT(*) FROM @ids)>20
     OR EXISTS(SELECT 1 FROM @ids WHERE id IS NULL OR id<=0)
     OR EXISTS(SELECT id FROM @ids GROUP BY id HAVING COUNT(*)>1)
   THROW 50003,'Seleccione entre 1 y 20 equipos sin repetir.',1;
  BEGIN TRANSACTION;
  DECLARE @tipo VARCHAR(20),@estado VARCHAR(20),@inicio DATETIME,@fin DATETIME,
    @anterior DECIMAL(10,2),@nuevo DECIMAL(10,2),@pagado DECIMAL(38,2),@cambios BIT=1;
  SELECT @tipo=tipo_reserva,@estado=estado,@inicio=fecha_inicio,@fin=fecha_fin,@anterior=monto_final
  FROM renta.Reserva WITH(UPDLOCK,HOLDLOCK) WHERE reserva_id=@reserva_id AND negocio_id=@negocio_id;
  IF @tipo IS NULL THROW 50001,'La reserva no existe en este negocio.',1;
  IF @tipo<>'Anticipada' OR @estado NOT IN ('Pendiente','Confirmada')
   THROW 50004,'Solo puede modificar anticipadas Pendiente o Confirmada.',1;
  IF NOT EXISTS(SELECT 1 FROM renta.Usuario u JOIN renta.Rol r ON r.rol_id=u.rol_id
    JOIN renta.Negocio n ON n.negocio_id=u.negocio_id
    WHERE u.usuario_id=@usuario_id AND n.negocio_id=@negocio_id AND n.estado='Activo'
    AND r.nombre IN ('Administrador','Operador'))
   THROW 50004,'El empleado o negocio no puede modificar reservas.',1;
  DECLARE @original TABLE(detalle_id INT,equipo_id INT,tarifa DECIMAL(10,2),entrega DATETIME,devolucion DATETIME);
  INSERT @original SELECT detalle_id,equipo_id,tarifa_aplicada,fecha_hora_entrega,fecha_hora_devolucion
  FROM renta.DetalleReserva WITH(UPDLOCK,HOLDLOCK) WHERE reserva_id=@reserva_id;
  IF EXISTS(SELECT 1 FROM @original WHERE entrega IS NOT NULL OR devolucion IS NOT NULL)
   THROW 50004,'No puede modificar una reserva con equipos entregados.',1;
  IF @inicio=@fecha_inicio AND @fin=@fecha_fin
     AND NOT EXISTS(SELECT equipo_id FROM @original EXCEPT SELECT id FROM @ids)
     AND NOT EXISTS(SELECT id FROM @ids EXCEPT SELECT equipo_id FROM @original)
   SET @cambios=0;
  DECLARE @equipos TABLE(id INT PRIMARY KEY,codigo VARCHAR(20),estado VARCHAR(20),negocio INT,tarifa DECIMAL(10,2));
  INSERT @equipos SELECT e.equipo_id,e.codigo_interno,e.estado,c.negocio_id,
    renta.fn_CalcularMontoAlquiler(c.tarifa_hora,c.tarifa_dia,@fecha_inicio,@fecha_fin)
  FROM renta.Equipo e WITH(UPDLOCK,HOLDLOCK) JOIN renta.CategoriaEquipo c WITH(HOLDLOCK) ON c.categoria_id=e.categoria_id
  WHERE e.equipo_id IN (SELECT id FROM @ids UNION SELECT equipo_id FROM @original);
  IF (SELECT COUNT(*) FROM @equipos e JOIN @ids i ON i.id=e.id WHERE e.negocio=@negocio_id)<>(SELECT COUNT(*) FROM @ids)
   THROW 50001,'Un equipo seleccionado no pertenece a este negocio.',1;
  IF EXISTS(SELECT 1 FROM @equipos e JOIN @ids i ON i.id=e.id WHERE e.estado IN ('Averiado','Mantenimiento','Fuera de servicio'))
   THROW 50004,'Un equipo seleccionado no esta en condiciones de reservarse.',1;
  IF EXISTS(SELECT 1 FROM renta.Mantenimiento m WITH(HOLDLOCK) JOIN @ids i ON i.id=m.equipo_id WHERE m.fecha_fin IS NULL)
   THROW 50004,'Un equipo seleccionado tiene mantenimiento abierto.',1;
  IF EXISTS(SELECT 1 FROM renta.DetalleReserva d WITH(HOLDLOCK)
    JOIN renta.Reserva r WITH(HOLDLOCK) ON r.reserva_id=d.reserva_id JOIN @ids i ON i.id=d.equipo_id
    WHERE r.reserva_id<>@reserva_id AND d.fecha_hora_devolucion IS NULL
    AND r.estado IN ('Pendiente','Confirmada','En curso') AND r.fecha_inicio<@fecha_fin AND r.fecha_fin>@fecha_inicio)
   THROW 50004,'Un equipo ya esta reservado en ese periodo. Su propia reserva no se cuenta como conflicto.',1;
  SELECT @pagado=ISNULL(SUM(monto),0) FROM renta.Pago WITH(HOLDLOCK) WHERE reserva_id=@reserva_id AND estado='Completado';
  IF @cambios=0 SET @nuevo=@anterior;
  ELSE SELECT @nuevo=SUM(CONVERT(DECIMAL(38,2),e.tarifa)) FROM @equipos e JOIN @ids i ON i.id=e.id;
  IF @nuevo<@pagado THROW 50004,'El nuevo total es menor que los abonos. No se admiten cambios que requieran reembolso.',1;
  DECLARE @version VARCHAR(64),@contenido NVARCHAR(MAX);
  SET @contenido=(SELECT @inicio inicio_original,@fin fin_original,@estado estado,@anterior total_anterior,
    @fecha_inicio inicio_nuevo,@fecha_fin fin_nuevo,@nuevo total_nuevo,@pagado abonos,
    (SELECT detalle_id,equipo_id,tarifa FROM @original ORDER BY detalle_id FOR JSON PATH) originales,
    (SELECT e.id,e.codigo,CASE WHEN @cambios=0 THEN o.tarifa ELSE e.tarifa END tarifa
      FROM @equipos e JOIN @ids i ON i.id=e.id LEFT JOIN @original o ON o.equipo_id=e.id ORDER BY e.id FOR JSON PATH) propuestos
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  SET @version=CONVERT(VARCHAR(64),HASHBYTES('SHA2_256',@contenido),2);
  IF GETDATE()>=@inicio OR GETDATE()>=@fecha_inicio
   THROW 50004,'Debe modificar antes del inicio original y el nuevo inicio debe seguir siendo futuro.',1;
  IF @confirmar=1 AND (@version_esperada IS NULL OR @version_esperada<>@version)
   THROW 50002,'La reserva, el precio o los abonos cambiaron. Revise el resumen y confirme otra vez.',1;
  IF @confirmar=1 AND @cambios=1
  BEGIN
   DELETE d FROM renta.DetalleReserva d WHERE d.reserva_id=@reserva_id AND NOT EXISTS(SELECT 1 FROM @ids i WHERE i.id=d.equipo_id);
   UPDATE d SET tarifa_aplicada=e.tarifa FROM renta.DetalleReserva d JOIN @equipos e ON e.id=d.equipo_id WHERE d.reserva_id=@reserva_id;
   INSERT renta.DetalleReserva(reserva_id,equipo_id,tarifa_aplicada)
   SELECT @reserva_id,e.id,e.tarifa FROM @equipos e JOIN @ids i ON i.id=e.id
   WHERE NOT EXISTS(SELECT 1 FROM renta.DetalleReserva d WHERE d.reserva_id=@reserva_id AND d.equipo_id=e.id);
   UPDATE renta.Reserva SET fecha_inicio=@fecha_inicio,fecha_fin=@fecha_fin,monto_final=@nuevo,
    estado=CASE WHEN @nuevo-@pagado=0 THEN 'Confirmada' ELSE 'Pendiente' END WHERE reserva_id=@reserva_id;
   EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=@usuario_id;
   -- Reconcile old and new units without freeing equipment in another rental.
   UPDATE e SET estado=CASE
     WHEN EXISTS(SELECT 1 FROM renta.DetalleReserva d WHERE d.equipo_id=e.equipo_id AND d.fecha_hora_entrega IS NOT NULL AND d.fecha_hora_devolucion IS NULL) THEN 'Alquilado'
     WHEN EXISTS(SELECT 1 FROM renta.DetalleReserva d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id
       WHERE d.equipo_id=e.equipo_id AND d.fecha_hora_devolucion IS NULL AND r.estado IN ('Pendiente','Confirmada','En curso')) THEN 'Reservado'
     ELSE 'Disponible' END
   FROM renta.Equipo e JOIN @equipos x ON x.id=e.equipo_id
   WHERE e.estado IN ('Disponible','Reservado','Alquilado');
   EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=NULL;
  END
  COMMIT;
  SELECT @anterior total_anterior,@nuevo total_nuevo,@pagado abonos,@nuevo-@pagado saldo,
    @cambios cambios,@version version,@fecha_inicio fecha_inicio,@fecha_fin fecha_fin;
  SELECT e.id equipo_id,e.codigo codigo_interno,CASE WHEN @cambios=0 THEN o.tarifa ELSE e.tarifa END tarifa
   FROM @equipos e JOIN @ids i ON i.id=e.id LEFT JOIN @original o ON o.equipo_id=e.id ORDER BY e.id;
 END TRY
 BEGIN CATCH
  EXEC sys.sp_set_session_context @key=N'usuario_actual',@value=NULL;
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH
END
GO
