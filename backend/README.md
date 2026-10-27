# RentaTica API

API REST para SQL Server. El inicio de sesion delega la verificacion de credenciales al SP
renta.usp_Auth_ValidarCredenciales y devuelve JWT con expiracion de 8 horas. Las rutas de
inventario delegan las consultas a SPs y toman negocio_id y rol de los claims firmados.

## Requisitos

- Node.js 20 o superior.
- SQL Server accesible desde la computadora que ejecuta el API.
- El usuario de Windows que ejecuta Node debe tener permiso para ejecutar los procedimientos
  almacenados usados por la API en RentaTicaDB.
- TCP/IP habilitado y SQL Server Browser accesible para resolver la instancia nombrada.

## Instalacion local

Desde esta carpeta:

1. Copie .env.example como .env.
2. Genere una clave JWT con node -e "console.log(require('node:crypto').randomBytes(48).toString('base64url'))".
3. Pegue el resultado en JWT_SECRET en .env. No comparta ni suba .env al repositorio.
4. Revise DB_SERVER. El valor inicial usa CCC\MSSQLSERVER01 y autenticacion integrada de Windows.
5. Ejecute npm.cmd install.
6. Ejecute npm.cmd run check.
7. Ejecute npm.cmd start.

La API escucha en http://localhost:3000. La documentacion interactiva esta en /docs y el
documento OpenAPI en /openapi.yaml. El endpoint /health confirma si la base esta conectada.

## Endpoints

- POST /api/auth/login con JSON {"email":"...","password":"..."} llama a
  renta.usp_Auth_ValidarCredenciales y devuelve un JWT.
- GET /api/equipos?estado=Disponible requiere Bearer JWT y rol Administrador u Operador;
  llama a renta.usp_Equipo_ListarPorEstado con el negocio_id del token.
- GET /api/reportes/inventario requiere Bearer JWT y rol Administrador u Operador; llama a
  renta.usp_Reporte_InventarioPorCategoria con el negocio_id del token.

En produccion, publique el servicio detras de HTTPS. La API no guarda credenciales SQL: usa
la identidad Windows que ejecuta el proceso y toma el secreto JWT de .env.

## Verificacion manual de la API

1. Ejecute una vez `database/05_tests/pruebas_api_preparar.sql` en SSMS y conserve el escenario hasta terminar.
2. En `backend`, copie `.env.example` a `.env`, genere y configure `JWT_SECRET`, y ejecute `npm.cmd install` y `npm.cmd start`.
3. Haga login con el correo y contrasena temporal que devuelve el script:

```powershell
$login = Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/api/auth/login' -ContentType 'application/json' -Body (@{ email = 'operador@api.prueba.test'; password = 'RentaTicaAPI2026!' } | ConvertTo-Json)
$headers = @{ Authorization = "Bearer $($login.token)" }
Invoke-RestMethod -Uri 'http://localhost:3000/api/equipos?estado=Disponible' -Headers $headers
```

4. La respuesta debe incluir el equipo `API-001`. Luego ejecute `database/05_tests/pruebas_api_limpiar.sql`.
