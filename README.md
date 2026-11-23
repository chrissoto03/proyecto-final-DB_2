# RentaTica

Proyecto SaaS para administrar alquileres de equipo. La lógica de negocio se
implementa en SQL Server y el API actúa como capa de transporte.

## Carpetas

- `backend/`: código del API REST Node/Express. Guía: `backend/README.md`.
- `cliente-dotnet/`: cliente Razor Pages para ejecutar la demostración desde
  Visual Studio morado; consume el API por HTTP y no reemplaza su lógica.
- `database/`: esquema, datos iniciales, funciones, procedimientos, triggers y
  pruebas SQL. Orden de instalación: [database/README.md](database/README.md).
- `docs/`: propuesta, requisitos del curso, diccionario y diagramas. Índice:
  [docs/README.md](docs/README.md). La metodología de R4 está en
  [docs/optimizacion/README.md](docs/optimizacion/README.md).
- `tools/`: utilidades Python de lectura para resumir planes SQL Server.

## Inicio

Para desplegar la base de datos, sigue el orden de `database/README.md`. Inicia
el API siguiendo `backend/README.md`. Para abrir la aplicación de demostración,
abre `cliente-dotnet/ClienteRentaTica.sln` en Visual Studio, selecciona
`ClienteRentaTica` como proyecto de inicio y pulsa F5; el navegador usa
`http://localhost:5180` y el API debe estar en `http://localhost:3000`. Guía detallada de uso: `cliente-dotnet/README.md`.

La captura y comparación de planes de ejecución de R4 se documenta en
`docs/optimizacion/README.md`. Captura los planes base antes de crear índices.
