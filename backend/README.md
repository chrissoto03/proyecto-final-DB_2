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

### Entrega de anticipadas

`POST /api/reservas/{reserva_id}/entrega` usa `usp_Reserva_Entregar`. Solo Administrador/Operador; negocio y usuario provienen del JWT. Entrega todos los equipos asignados sin aceptar IDs de equipo, fechas ni negocio del cuerpo. Exige Confirmada, saldo cero y horario SQL `[fecha_inicio, fecha_fin)`. Devuelve la ficha, cuyo encabezado agrega `hora_servidor` y cuyos detalles agregan `estado_equipo`. El depósito no cuenta como pago del alquiler.

Prueba independiente con limpieza de sus propios datos: `node tests/entrega.cjs`. No reinicia el escenario api-flujo.

### Modificación de anticipadas

Rutas bajo `/api/reservas/{id}/modificacion`: `GET equipos`, `POST revisar` y `POST confirmar`. Requieren Administrador/Operador y negocio del JWT. `revisar` recibe fechas locales sin zona y equipo_ids; devuelve comparación de importes y confirmación firmada. `confirmar` recibe solo `confirmacion`; SQL recalcula y compara la versión antes de guardar. Un 409 puede incluir un nuevo resumen/token que debe mostrarse y confirmarse de nuevo. No reintentar automáticamente. Precio acordado sin cambios, pagos preservados y garantía separada.

Prueba aislada: `node tests/modificacion.cjs`. No reinicia api-flujo ni modifica reservas del usuario. El transporte de fechas de estas rutas conserva la hora local almacenada en SQL, sin aplicar la zona horaria del proceso Node.

### Contrato de fechas locales

Las rutas de creación, consulta de disponibilidad y modificación usan `src/lib/business-date.js`. Reciben `YYYY-MM-DDTHH:mm[:ss[.SSS]]` como hora local del negocio y preservan esos campos en SQL datetime, independientemente de la zona del proceso Node. Por compatibilidad admiten Z como representación del mismo valor SQL; no deben enviarse offsets como -06:00. Validan fechas reales del calendario y el mínimo de SQL datetime (1753). No convertir una hora local a un instante UTC antes de enviarla.

Walk-in delega inicio y validación del fin a SQL Server, sin comparar una hora local con Date.now(). La corrección solo afecta solicitudes nuevas; no desplaza registros existentes. Prueba aislada: `node tests/horas-inventario.cjs`. Con CLIENT_URL y TEST_API_PORT incluye las tablas Razor, igual que la prueba de modificación.

## Fechas y mantenimiento de equipos

Los formularios de creación y modificación ofrecen fecha y hora separadas, con un resumen legible del día y hora del negocio. Conservan la precisión original mientras no se editen y mantienen el control nativo como alternativa sin JavaScript. La agenda mensual de reservas queda para una entrega posterior.

Desde **Inventario y reportes**, consulta **Averiado** y abre el código del equipo. Su ficha muestra reservas asociadas e historial. Registra descripción, tipo y costo para iniciar mantenimiento; al finalizar elige explícitamente reparado, sigue averiado o fuera de servicio. Reparado queda Disponible, o Reservado si conserva reservas activas. Reparar no cancela reservas ni cobra al cliente: abonos y garantía permanecen separados.

Se bloquean órdenes abiertas duplicadas, cierre repetido, costos inválidos, equipos pendientes de devolución y operaciones de otro negocio o rol. SQL guarda cada transición en una transacción, con usuario autenticado para auditoría. No se reparó automáticamente FLUJO-002.

Instalar las versiones de usp_Mantenimiento_Crear.sql, usp_Mantenimiento_Finalizar.sql y usp_Equipo_ObtenerPorId.sql de database/03_procedures (ya instaladas localmente). Finalizar ahora exige usuario_id de un empleado activo del negocio. Se conservan 78 SP, 6 funciones y 2 triggers. Reinicia el API y el cliente para probar.

Prueba aislada: node backend/tests/mantenimiento.cjs. Con CLIENT_URL y TEST_API_PORT también recorre los formularios Razor con antiforgery. Crea y elimina únicamente su negocio temporal.

Verificación de esta entrega: compilación .NET sin errores, sintaxis API, YAML OpenAPI y pruebas SQL/API/Razor de mantenimiento correctas (incluido Fuera de servicio). La inspección en el navegador integrado mostró el formulario nativo, pero no ejecutó la mejora JavaScript; la apariencia y la interacción del selector mejorado quedan pendientes de comprobar en el navegador habitual. El archivo JavaScript respondió HTTP 200 y pasó la comprobación de sintaxis.
