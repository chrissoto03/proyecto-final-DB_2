# RentaTica API

API REST para SQL Server. La autenticación delega al SP `renta.usp_Auth_ValidarCredenciales`; las rutas reciben JWT y ejecutan procedimientos almacenados. El negocio y el usuario se toman de los claims firmados, nunca del cuerpo enviado por el cliente.

## Requisitos e instalación

- Node.js 20 o superior.
- SQL Server accesible desde la computadora que ejecuta el API.
- El usuario de Windows que ejecuta Node debe tener permiso de ejecutar los SPs usados por la API en `RentaTicaDB`.
- TCP/IP habilitado y SQL Server Browser accesible para resolver `CCC\MSSQLSERVER01`.

Desde esta carpeta:

1. Copia `.env.example` a `.env` si aún no existe.
2. Configura un `JWT_SECRET` aleatorio de al menos 32 bytes; no lo compartas ni lo subas.
3. Revisa `DB_SERVER=CCC\MSSQLSERVER01` y `DB_NAME=RentaTicaDB`.
4. Ejecuta `npm.cmd install` una vez.
5. Ejecuta `npm.cmd run check`.
6. Ejecuta `npm.cmd start`.

El API escucha en `http://localhost:3000`; la salud es `/health`, Swagger en `/docs` y OpenAPI en `/openapi.yaml`.

## Endpoints principales

- `POST /api/auth/login`: autentica con `usp_Auth_ValidarCredenciales` y entrega JWT de 8 horas.
- `GET /api/equipos?estado=Disponible`: inventario del negocio, SP `usp_Equipo_ListarPorEstado`.
- `GET /api/reportes/inventario`: SP `usp_Reporte_InventarioPorCategoria`.
- `GET /api/clientes`, `GET /api/metodos-pago`: catálogos para el formulario de reserva/pago.
- `POST /api/reservas`: ejecuta `usp_Reserva_Crear` con el operador del token, el cliente, rango y arreglo de IDs de equipo.
- `GET /api/reservas?estado=En%20curso` lista reservas del negocio (filtro opcional); `GET /api/reservas/proximas?dias=30` y `GET /api/reservas/{reserva_id}`: lista/detalle por negocio; el detalle incluye cada `detalle_id` necesario para devolución.
- `POST /api/reservas/{reserva_id}/pagos`: SP `usp_Pago_Registrar`.
- `POST /api/devoluciones/{detalle_id}`: SP `usp_Equipo_Devolver`; el usuario de auditoría viene del JWT.

Las reglas de reserva, pago, disponibilidad, estados y devolución siguen en SQL Server. La API valida el formato HTTP y convierte errores conocidos de SP a respuestas HTTP.

## Prueba manual del ciclo en SSMS y .NET

1. Ejecuta `database/05_tests/13_preparar_flujo_api.sql` una vez en SSMS. Guarda los IDs que devuelve (en especial `cliente_id`) y las credenciales temporales.
2. Inicia el API con `npm.cmd start`; confirma `http://localhost:3000/health`.
3. Abre `cliente-dotnet/ClienteRentaTica.sln` en Visual Studio y pulsa F5. Inicia sesión con el operador temporal.
4. En **Nueva reserva**, selecciona cliente, FLUJO-001 y Walk-in. Al crearla se abre su ficha.
5. En la ficha registra el pago por el saldo pendiente usando Efectivo.
6. Devuelve FLUJO-001 desde su ficha con condición Bueno. El equipo vuelve a Disponible y la reserva pasa a Completada.
7. Revisa **Consultar equipos** y **Reporte por categoría**.
8. Detén el cliente y el API; en SSMS ejecuta `database/05_tests/14_limpiar_flujo_api.sql`.

También puedes probar las mismas rutas en Swagger `/docs`, primero usando `POST /api/auth/login` y luego autorizando con el JWT. No compartas el token.

- `GET /api/equipos/disponibilidad?fecha_inicio=2026-12-01T08:00:00&fecha_fin=2026-12-01T12:00:00`: equipos libres para el rango, importe estimado y tarifa de garantía de categoría. Usa `usp_Equipo_ConsultarDisponibilidad`; el negocio se toma del JWT. Requiere Administrador u Operador. Las fechas siguen el formato local sin zona usado por el formulario de reserva. Consultar no bloquea equipos; crear la reserva vuelve a validar dentro de la transacción.
- Prueba de solo lectura: `node tests/disponibilidad.cjs`; requiere una reserva anticipada futura existente y configuración SQL del API. No reinicia escenarios ni modifica datos.
