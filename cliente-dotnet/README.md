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


La consulta de disponibilidad mantiene el formulario abierto y lleva la vista al bloque **Selecciona el equipo**. No crea la reserva: el operador elige una unidad y pulsa **Crear reserva**. Al cambiar fechas se invalida la selección. La lista muestra las mismas horas del negocio que la ficha, sin convertirlas a la zona horaria del servidor web.

## Entrega de reservas anticipadas

1. Reinicia el API (`npm.cmd start` desde backend), abre la solución y pulsa F5.
2. Abre una anticipada desde **Ver detalle**. Admite abonos; al pagar el saldo completo pasa de Pendiente a Confirmada.
3. Antes del inicio, la ficha indica que aún no se puede entregar. Desde el inicio previsto y antes del fin, actualiza la ficha: aparece **Entregar equipos** si está Confirmada, sin deuda y con equipos aptos.
4. Comprueba los códigos y pulsa **Entregar equipos**. Se entregan todos juntos; la reserva pasa a En curso y muestra la hora real. No se modifica el importe ni el depósito.
5. Devuelve cada equipo desde la ficha. La reserva se completa cuando se devuelven todos, con las reglas existentes del depósito.

SQL usa su propio reloj después de adquirir los bloqueos. Rechaza equipos averiados, en mantenimiento, fuera de servicio, alquilados, con mantenimiento abierto o entregados sin devolver en otro alquiler, aunque su período ya terminara. Revalida las asignaciones en la transacción. La interfaz usa la hora SQL recibida al consultar; actualiza la ficha cuando llegue el horario. SQL vuelve a validar al guardar.

Instalación: ejecutar `database/03_procedures/Reserva/transactions/usp_Reserva_Entregar.sql` y `database/03_procedures/Reserva/procedures/usp_Reserva_ObtenerPorId.sql`. Ya se instalaron localmente. Inventario: 77 SP, 6 funciones y 2 triggers.

Pruebas: `node backend/tests/entrega.cjs` crea un negocio temporal independiente y lo elimina al terminar. Cubre abonos, saldo separado de garantía, horario, vencimiento durante espera de bloqueo, estados, mantenimiento, otro alquiler sin devolución, asignación duplicada, negocio/rol incorrectos, entrega concurrente, auditoría, devolución y Walk-in.

Para incluir el formulario Razor: inicia el cliente temporal con la variable `RentaTicaApi__BaseUrl=http://127.0.0.1:3001/` y URL `http://localhost:5182`; ejecuta el test con `TEST_API_PORT=3001` y `CLIENT_URL=http://localhost:5182`. La prueba inicia y detiene su propio API. Se verificó el formulario real por HTTP con sesión y antiforgery, además de compilar; no se hizo una nueva inspección visual en esta entrega.

La reserva futura del usuario se conservó, sin adelantar fechas ni completar pagos. Modificación, cancelación y cargos por atraso quedan para entregas posteriores.

## Modificar una reserva anticipada

1. Reinicia el API y ejecuta el cliente con F5. Abre una reserva anticipada futura desde **Ver detalle**.
2. Pulsa **Modificar fechas y equipos**. Solo aparece para Pendiente/Confirmada, antes del inicio y sin equipos entregados.
3. Ajusta fechas y marca los equipos por código. Los equipos del catálogo no están necesariamente libres para ese rango: **Revisar cambios y precio** lo comprueba excluyendo la propia reserva.
4. Compara total anterior, nuevo total, abonos y saldo. La revisión no guarda ni aparta equipos. Si fechas y equipos no cambian, conserva el precio acordado; en caso contrario usa las tarifas actuales.
5. Pulsa **Confirmar modificación**. Si cambiaron los pagos, el precio o la reserva, verás una revisión actualizada y tendrás que confirmar otra vez. Si otra reserva ocupa un equipo o ya pasó el inicio, se rechaza y conserva los datos originales.
6. Al guardar regresa a la ficha: saldo positivo queda Pendiente y saldo cero Confirmada. No se admiten totales inferiores a los abonos. El depósito queda separado e intacto.

No se permite modificar después del inicio original ni mover el nuevo inicio al pasado. Se conservan los IDs de detalle de los equipos que permanecen; el inventario de equipos retirados considera sus otras reservas y entregas. Las confirmaciones duran 15 minutos y pertenecen a una reserva, un negocio y un usuario; no se guardan en una variable compartida de sesión.

SQL: instalar `database/03_procedures/Reserva/transactions/usp_Reserva_Modificar.sql` (ya instalado localmente). El inventario pasa a 78 SP, 6 funciones y 2 triggers. No se requiere recrear tablas o reiniciar el escenario 13.

Verificación: `node backend/tests/modificacion.cjs` crea y elimina únicamente su propio negocio temporal. Cubre revisión sin escrituras, precio conservado sin cambios, autorreserva excluida, equipos ocupados, tarifas y abonos que cambian entre pasos, dos confirmaciones simultáneas, estados y horario, equipos ajenos, token alterado, total menor que abonos y rollback provocado después de escribir detalles. Se verificó el formulario Razor por HTTP, incluida la segunda confirmación por cambio de tarifa.

Para incluir Razor en la prueba, inicia el cliente desde su carpeta con `RentaTicaApi__BaseUrl=http://127.0.0.1:3001/` y `--urls http://localhost:5182`; ejecuta el test con `TEST_API_PORT=3001` y `CLIENT_URL=http://localhost:5182`. El test inicia su API y lo cierra al terminar. Requiere permisos SQL para crear el escenario y el trigger de fallo controlado; este se crea dentro de una transacción que se revierte y se verifica que desaparece. No se hizo una nueva inspección visual en navegador en esta entrega.
