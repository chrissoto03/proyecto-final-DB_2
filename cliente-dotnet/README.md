# Cliente .NET de RentaTica

Aplicación de demostración en Razor Pages. Permite crear reservas, registrar pagos y devoluciones, consultar inventario y ver las reservas del negocio. La lógica de negocio y las transacciones se ejecutan en los procedimientos almacenados de SQL Server; el cliente .NET consume el API Node por HTTP.

## Requisitos

- SQL Server en `CCC\MSSQLSERVER01` con `RentaTicaDB` instalada.
- Node.js y dependencias instaladas en `backend`.
- Visual Studio con la carga de trabajo ASP.NET y SDK .NET 10.

## Iniciar todo en orden

1. **Preparar datos en SSMS:** conecta a `CCC\MSSQLSERVER01`, abre `database/05_tests/13_preparar_flujo_api.sql` y ejecuta el archivo completo en `RentaTicaDB`. El script crea el negocio de prueba, el operador, un cliente y tres equipos (`FLUJO-001`, `FLUJO-002` y `FLUJO-003`). Anota el correo y la contraseña temporal que aparecen en los resultados.
2. **Iniciar el API:** abre una terminal en la carpeta `backend`. Si es la primera vez, sigue la instalación de `backend/README.md`; después ejecuta `npm.cmd run check` y `npm.cmd start`. Deja esa terminal abierta. Comprueba `http://localhost:3000/health`; debe indicar que SQL Server está conectado.
3. **Iniciar el cliente .NET:** en Visual Studio morado abre `ClienteRentaTica.sln`, selecciona `ClienteRentaTica` como proyecto de inicio y pulsa **F5**. El navegador abre `http://localhost:5180`. El cliente no inicia el API automáticamente.
4. **Iniciar sesión:** usa el correo y la contraseña temporal del paso 1.

## Crear y consultar reservas

1. En **Nueva reserva**, selecciona el cliente temporal y un equipo disponible. Puedes crear hasta tres reservas simultáneas usando distintos equipos `FLUJO-001` a `FLUJO-003`.
2. Para **Walk-in**, la hora de inicio la asigna SQL Server al crear la reserva; asegúrate de que la fecha final sea futura. Para **Anticipada**, selecciona también una fecha de inicio futura.
3. Después de crear la reserva, consulta **Reservas del negocio**, debajo de los formularios. La lista muestra cliente, estado, tipo, fechas, cantidad de equipos y total; se actualiza después de crear, pagar o devolver. Usa el filtro de estado y **Actualizar lista** para encontrar una reserva.
4. Abre **Ver detalle** en la reserva que quieres atender y registra el abono o pago del saldo.
5. Desde esa misma ficha, devuelve el equipo identificado por su código.
6. En **Inventario y reportes**, consulta los estados del equipo y el reporte por categoría para confirmar los cambios.

## Limpiar los datos de prueba

Cuando termines, en SSMS ejecuta el archivo completo `database/05_tests/14_limpiar_flujo_api.sql` en `RentaTicaDB`. Elimina únicamente el escenario `api-flujo`: sus reservas, operador, cliente, categoría, tres equipos y negocio temporal. No elimina datos de otros negocios.

Para repetir las pruebas, vuelve al paso 1. El script 13 reemplaza únicamente el escenario temporal con el mismo correo de contacto.

## Direcciones útiles

- Salud del API: `http://localhost:3000/health`.
- Swagger: `http://localhost:3000/docs`.
- Cliente .NET: `http://localhost:5180`.
- Detalles de instalación y rutas: `backend/README.md`.
## Gestionar una reserva desde su ficha

1. Inicia el API con `npm.cmd start` en `backend`.
2. Abre `ClienteRentaTica.sln` en Visual Studio, selecciona el proyecto y pulsa F5.
3. Inicia sesión. Crea una reserva Walk-in: se abre automáticamente su ficha.
4. Regresa a la lista y crea otra reserva con otro equipo. Abre las dos fichas en pestañas distintas mediante **Ver detalle**.
5. En la primera, registra un abono menor que el saldo. Comprueba el total pagado y el saldo actualizado. Registra luego el saldo restante.
6. Devuelve el equipo desde su código con condición **Bueno**. La ficha muestra la devolución y la reserva completada; el inventario vuelve a mostrar el equipo disponible.
7. Actualiza la segunda pestaña: su estado y saldo deben permanecer iguales.

La ficha muestra pagos y depósitos, conserva la reserva en su URL y vuelve a ella después de guardar. Las devoluciones solo se ofrecen para equipos entregados, aún no devueltos, de reservas en curso. Operadores y administradores pueden pagar y devolver según las reglas del API. Una reserva completada con deuda admite un pago; una cancelada no. La última devolución con depósito requiere indicar devolución y retención, sin asumir una política comercial.

### SQL que actualizar

Ejecuta en SSMS `database/03_procedures/Equipo/transactions/usp_Equipo_Devolver.sql` (ruta desde la raíz). Usa CREATE OR ALTER: no recrea tablas. Valida que el equipo haya sido entregado y serializa las devoluciones de una misma reserva. Ya se instaló en la instancia local durante esta entrega.

### Verificación realizada el 26/11/2026

- Compilación .NET y revisión de sintaxis del API correctas.
- Prueba HTTP de los formularios Razor reales con cookies de sesión y antiforgery: lista, dos fichas abiertas en la misma sesión, abono, pago restante y devolución. La segunda reserva conserva todos sus datos.
- Se rechaza enviar desde la ficha A el detalle de B.
- Un operador temporal de otro negocio recibe rechazo al consultar, pagar y devolver por ID; la reserva no cambia. El negocio y operador de aislamiento se eliminaron al terminar.
- Equipo devuelto disponible y reserva completada con saldo cero.
- Se corrigió la lectura de importes decimales para no depender de la configuración regional de Windows.

No se hizo inspección visual en navegador ni prueba de carga concurrente. Queda pendiente verificar depósitos con retenciones, condiciones Averiado/Perdido y el ciclo completo de reservas anticipadas.

La prueba reproducible está en `backend/tests/ficha.cjs`: requiere el escenario 13 sin reservas activas sobre FLUJO-001/002, el API en 3000 y el cliente en 5181 (`dotnet run --project cliente-dotnet/ClienteRentaTica --urls http://localhost:5181`). Ejecuta `node backend/tests/ficha.cjs` desde la raíz. Crea dos reservas y las conserva para inspección; no reinicia ni limpia automáticamente el escenario. Revisa los datos antes de ejecutar los scripts 13 o 14.

## Disponibilidad para reservas anticipadas

En **Nueva reserva**, selecciona **Anticipada**, indica inicio y fin y pulsa **Consultar disponibilidad**. Luego selecciona el equipo y crea la reserva. El listado considera el período, aunque el equipo figure como Reservado por otro alquiler. Si cambias el rango, vuelve a consultar. El importe mostrado es una estimación del alquiler; SQL vuelve a comprobar disponibilidad y calcular el importe al guardar.

La ficha distingue **Total del alquiler**, **Abonos al alquiler** y **Saldo del alquiler**. Un abono no crea ni liquida un depósito de garantía. Por ahora se pueden consultar depósitos existentes y liquidarlos al devolver; todavía no existe una operación de registro de garantías en la aplicación.

Instalación SQL de esta entrega: ejecutar `database/02_functions/Equipo/fn_EquipoEstaDisponible.sql` y `database/02_functions/Equipo/fn_EquiposDisponibles.sql`. Ambas excluyen equipos en mantenimiento, igual que la creación de reservas. Ya se instalaron localmente. No se modificaron reservas ni pagos del usuario.

Verificación: compilación sin errores, sintaxis del API, prueba de disponibilidad contra SQL real (`node backend/tests/disponibilidad.cjs`) y formularios Razor por HTTP con sesión y antiforgery. Se verificaron solapamiento, rango libre con estimación, fechas inválidas, rol no autorizado y negocio inexistente. No se hizo inspección visual ni se implementaron todavía entrega, modificación, cancelación o atrasos de anticipadas.
