/* Inventario fuente del proyecto: 76 SP (incluye 6 transaccionales), 6 funciones y 2 triggers.
   Ejecutar despues de instalar los scripts de database/02_functions, 03_procedures y 04_triggers.
   Detecta nombres ausentes y objetos inesperados dentro del esquema renta.
*/
USE RentaTicaDB;
GO
SET NOCOUNT ON;
DECLARE @Esperados TABLE(tipo VARCHAR(12) NOT NULL, nombre SYSNAME NOT NULL, PRIMARY KEY(tipo,nombre));
INSERT INTO @Esperados(tipo,nombre) VALUES
    ('FUNCTION', N'fn_CalcularMontoAlquiler'),
    ('FUNCTION', N'fn_EquipoEstaDisponible'),
    ('FUNCTION', N'fn_EquiposDisponibles'),
    ('FUNCTION', N'fn_HashPassword'),
    ('FUNCTION', N'fn_RolRequiereNegocio'),
    ('FUNCTION', N'fn_VerificarPassword'),
    ('PROCEDURE', N'usp_AuditoriaEquipo_Listar'),
    ('PROCEDURE', N'usp_AuditoriaEquipo_ListarPorEquipo'),
    ('PROCEDURE', N'usp_AuditoriaEquipo_ListarPorUsuario'),
    ('PROCEDURE', N'usp_CategoriaEquipo_Crear'),
    ('PROCEDURE', N'usp_CategoriaEquipo_Eliminar'),
    ('PROCEDURE', N'usp_CategoriaEquipo_Listar'),
    ('PROCEDURE', N'usp_CategoriaEquipo_Modificar'),
    ('PROCEDURE', N'usp_CategoriaEquipo_ObtenerPorId'),
    ('PROCEDURE', N'usp_Deposito_Listar'),
    ('PROCEDURE', N'usp_Deposito_ObtenerPorReserva'),
    ('PROCEDURE', N'usp_Deposito_ResumenPendientes'),
    ('PROCEDURE', N'usp_DetalleReserva_ListarPorReserva'),
    ('PROCEDURE', N'usp_DetalleReserva_ObtenerPorId'),
    ('PROCEDURE', N'usp_Equipo_ActualizarEstado'),
    ('PROCEDURE', N'usp_Equipo_ConsultarDisponibilidad'),
    ('PROCEDURE', N'usp_Equipo_Crear'),
    ('PROCEDURE', N'usp_Equipo_Eliminar'),
    ('PROCEDURE', N'usp_Equipo_Listar'),
    ('PROCEDURE', N'usp_Equipo_ListarConMantenimientoAbierto'),
    ('PROCEDURE', N'usp_Equipo_ListarPorEstado'),
    ('PROCEDURE', N'usp_Equipo_Modificar'),
    ('PROCEDURE', N'usp_Equipo_ObtenerPorId'),
    ('PROCEDURE', N'usp_Equipo_Devolver'),
    ('PROCEDURE', N'usp_Mantenimiento_Eliminar'),
    ('PROCEDURE', N'usp_Mantenimiento_Listar'),
    ('PROCEDURE', N'usp_Mantenimiento_ListarPorEquipo'),
    ('PROCEDURE', N'usp_Mantenimiento_Modificar'),
    ('PROCEDURE', N'usp_Mantenimiento_ObtenerPorId'),
    ('PROCEDURE', N'usp_Mantenimiento_Crear'),
    ('PROCEDURE', N'usp_Mantenimiento_Finalizar'),
    ('PROCEDURE', N'usp_MetodoPago_Crear'),
    ('PROCEDURE', N'usp_MetodoPago_Eliminar'),
    ('PROCEDURE', N'usp_MetodoPago_Listar'),
    ('PROCEDURE', N'usp_MetodoPago_Modificar'),
    ('PROCEDURE', N'usp_MetodoPago_ObtenerPorId'),
    ('PROCEDURE', N'usp_Negocio_CambiarEstado'),
    ('PROCEDURE', N'usp_Negocio_Crear'),
    ('PROCEDURE', N'usp_Negocio_Eliminar'),
    ('PROCEDURE', N'usp_Negocio_Listar'),
    ('PROCEDURE', N'usp_Negocio_Modificar'),
    ('PROCEDURE', N'usp_Negocio_ObtenerPorId'),
    ('PROCEDURE', N'usp_Pago_Listar'),
    ('PROCEDURE', N'usp_Pago_ListarPorCliente'),
    ('PROCEDURE', N'usp_Pago_ListarPorReserva'),
    ('PROCEDURE', N'usp_Pago_ObtenerPorId'),
    ('PROCEDURE', N'usp_Pago_ResumenPorMetodo'),
    ('PROCEDURE', N'usp_Pago_Registrar'),
    ('PROCEDURE', N'usp_Reporte_ClientesFrecuentes'),
    ('PROCEDURE', N'usp_Reporte_IngresosPorDia'),
    ('PROCEDURE', N'usp_Reporte_InventarioPorCategoria'),
    ('PROCEDURE', N'usp_Reporte_MantenimientoCostos'),
    ('PROCEDURE', N'usp_Reporte_OcupacionEquipo'),
    ('PROCEDURE', N'usp_Reserva_CantidadPorEstado'),
    ('PROCEDURE', N'usp_Reserva_DisponibilidadPorCategoria'),
    ('PROCEDURE', N'usp_Reserva_Listar'),
    ('PROCEDURE', N'usp_Reserva_ListarPorCliente'),
    ('PROCEDURE', N'usp_Reserva_ListarVencidas'),
    ('PROCEDURE', N'usp_Reserva_ObtenerPorId'),
    ('PROCEDURE', N'usp_Reserva_Proximas'),
    ('PROCEDURE', N'usp_Reserva_Crear'),
    ('PROCEDURE', N'usp_Reserva_Eliminar'),
    ('PROCEDURE', N'usp_Rol_Crear'),
    ('PROCEDURE', N'usp_Rol_Eliminar'),
    ('PROCEDURE', N'usp_Rol_Listar'),
    ('PROCEDURE', N'usp_Rol_Modificar'),
    ('PROCEDURE', N'usp_Rol_ObtenerPorId'),
    ('PROCEDURE', N'usp_Auth_ValidarCredenciales'),
    ('PROCEDURE', N'usp_Usuario_CambiarPassword'),
    ('PROCEDURE', N'usp_Usuario_CambiarRol'),
    ('PROCEDURE', N'usp_Usuario_Crear'),
    ('PROCEDURE', N'usp_Usuario_CrearEmpleado'),
    ('PROCEDURE', N'usp_Usuario_Eliminar'),
    ('PROCEDURE', N'usp_Usuario_Listar'),
    ('PROCEDURE', N'usp_Usuario_Modificar'),
    ('PROCEDURE', N'usp_Usuario_ObtenerPorId'),
    ('PROCEDURE', N'usp_Usuario_Registrar'),
    ('TRIGGER', N'trg_Equipo_AuditarEstado'),
    ('TRIGGER', N'trg_Usuario_ValidarNegocio');
DECLARE @Actuales TABLE(tipo VARCHAR(12) NOT NULL, nombre SYSNAME NOT NULL, PRIMARY KEY(tipo,nombre));
INSERT INTO @Actuales(tipo,nombre)
SELECT 'PROCEDURE', p.name FROM sys.procedures p JOIN sys.schemas s ON s.schema_id=p.schema_id WHERE s.name='renta';
INSERT INTO @Actuales(tipo,nombre)
SELECT 'FUNCTION', o.name FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id WHERE s.name='renta' AND o.type IN('FN','IF','TF');
INSERT INTO @Actuales(tipo,nombre)
SELECT 'TRIGGER', t.name FROM sys.triggers t JOIN sys.objects o ON o.object_id=t.object_id WHERE OBJECT_SCHEMA_NAME(t.object_id)='renta' AND t.parent_class=1;

SELECT tipos.tipo, ISNULL(e.total,0) AS esperados, ISNULL(a.total,0) AS encontrados
FROM (VALUES ('PROCEDURE'),('FUNCTION'),('TRIGGER')) tipos(tipo)
LEFT JOIN (SELECT tipo,COUNT(*) total FROM @Esperados GROUP BY tipo) e ON e.tipo=tipos.tipo
LEFT JOIN (SELECT tipo,COUNT(*) total FROM @Actuales GROUP BY tipo) a ON a.tipo=tipos.tipo
ORDER BY tipos.tipo;

SELECT e.tipo,e.nombre,'FALTA EN SQL SERVER' AS estado
FROM @Esperados e LEFT JOIN @Actuales a ON a.tipo=e.tipo AND a.nombre=e.nombre WHERE a.nombre IS NULL
UNION ALL
SELECT a.tipo,a.nombre,'NO ESTA EN LOS SCRIPTS' AS estado
FROM @Actuales a LEFT JOIN @Esperados e ON e.tipo=a.tipo AND e.nombre=a.nombre WHERE e.nombre IS NULL;

IF EXISTS(SELECT 1 FROM @Esperados e LEFT JOIN @Actuales a ON a.tipo=e.tipo AND a.nombre=e.nombre WHERE a.nombre IS NULL)
   OR EXISTS(SELECT 1 FROM @Actuales a LEFT JOIN @Esperados e ON e.tipo=a.tipo AND e.nombre=a.nombre WHERE e.nombre IS NULL)
    THROW 51001,'El catalogo de objetos de SQL Server no coincide con el inventario fuente.',1;
PRINT 'Inventario SQL coincide: 76 procedimientos, 6 funciones y 2 triggers.';
GO