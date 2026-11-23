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
4. En **Registrar pago**, verifica el ID y saldo sugeridos. Si estás trabajando con una reserva anterior, usa su ID de la lista y el saldo correspondiente. La respuesta del API también muestra el detalle de la reserva.
5. En **Devolver equipo**, usa el ID de detalle que aparece en la respuesta de creación y elige el estado de devolución. Con **Bueno**, la reserva se completa y el equipo vuelve a estar disponible.
6. En **Inventario y reportes**, consulta los estados del equipo y el reporte por categoría para confirmar los cambios.

## Limpiar los datos de prueba

Cuando termines, en SSMS ejecuta el archivo completo `database/05_tests/14_limpiar_flujo_api.sql` en `RentaTicaDB`. Elimina únicamente el escenario `api-flujo`: sus reservas, operador, cliente, categoría, tres equipos y negocio temporal. No elimina datos de otros negocios.

Para repetir las pruebas, vuelve al paso 1. El script 13 reemplaza únicamente el escenario temporal con el mismo correo de contacto.

## Direcciones útiles

- Salud del API: `http://localhost:3000/health`.
- Swagger: `http://localhost:3000/docs`.
- Cliente .NET: `http://localhost:5180`.
- Detalles de instalación y rutas: `backend/README.md`.