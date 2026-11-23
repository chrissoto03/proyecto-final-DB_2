# Cliente de demostración RentaTica (.NET)

Aplicación Razor Pages para probar desde Visual Studio el API REST existente. El cliente inicia sesión mediante `POST /api/auth/login`, conserva el JWT en una sesión de servidor, consulta equipos y solicita el reporte de inventario. No implementa reglas de negocio: envía solicitudes HTTP al API y presenta las respuestas.

## Requisitos

- Visual Studio con desarrollo ASP.NET y SDK .NET 10.
- SQL Server y el API en `http://localhost:3000`.

## Ejecutar

1. Abre `ClienteRentaTica.sln` en Visual Studio.
2. Selecciona el proyecto `ClienteRentaTica` como proyecto de inicio.
3. Pulsa F5. El navegador abre `http://localhost:5180`.
4. Inicia sesión con el usuario temporal que prepara `database/05_tests/pruebas_api_preparar.sql`.
5. Consulta equipos por estado y el reporte de inventario.

El API sigue como proceso independiente. Su URL se configura en `ClienteRentaTica/appsettings.json`. Las llamadas HTTP se hacen desde el servidor Razor Pages.

Para una demostración, prepara antes el usuario con `pruebas_api_preparar.sql`; al terminar, limpia el escenario con `pruebas_api_limpiar.sql`.

