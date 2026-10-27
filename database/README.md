# RentaTica - SQL Server

SQL Server 2019 o posterior. El esquema de negocio es `renta`; la lógica de
negocio vive en funciones y procedimientos almacenados.

## Organización

- `00_schema/`: crea la base `RentaTicaDB` y el esquema `renta`.
- `00_schema/01_tablas/`: un archivo para cada una de las 12 tablas, en orden
  de dependencias.
- `01_seed/`: catálogos iniciales (roles y métodos de pago).
- `02_functions/<Entidad>/`: un archivo por función, guardado con su entidad.
- `03_procedures/<Entidad>/procedures/`: un archivo por procedimiento normal.
- `03_procedures/<Entidad>/transactions/`: los procedimientos con
  transacciones explícitas, separados por entidad.
- `04_triggers/<Entidad>/`: un archivo por trigger.
- `05_tests/`: pruebas por avance y escenarios de integración.
- `06_validation/01_verificar_inventario_objetos.sql`: compara el inventario
  fuente con los objetos instalados en SQL Server.
- Los archivos combinados que quedaron en la raíz de las carpetas numeradas son
  avisos obsoletos, sin definiciones SQL. No ejecutarlos.

## Inventario y cómo se cuenta

El código fuente contiene **76 procedimientos almacenados, 6 funciones y 2
triggers**. Los seis procedimientos que usan transacciones explícitas forman
parte de los 76 procedimientos; no son objetos adicionales:

- Transacciones: `usp_Mantenimiento_Crear`, `usp_Mantenimiento_Finalizar`,
  `usp_Reserva_Eliminar`, `usp_Reserva_Crear`, `usp_Pago_Registrar` y
  `usp_Equipo_Devolver`.
- `sys.procedures` cuenta procedimientos almacenados, incluidas esas seis
  transacciones. No cuenta funciones ni triggers.
- Las seis funciones y los dos triggers se consultan en catálogos de sistema
  distintos.

Antes de separar los objetos, estaban agrupados en seis archivos de
procedimientos: 16 + 10 + 18 + 13 + 3 + 16 = **76**. No faltaba ningún SP;
el problema era que varios objetos y transacciones estaban mezclados en
archivos temáticos, por lo que no se veía el conteo por entidad. Ahora cada
definición está en su propio archivo. La verificación recorre nombre por nombre.

## Orden de instalación en una base nueva

1. Ejecutar `00_schema/00_base_datos_y_esquema.sql`.
2. Ejecutar los archivos `.sql` de `00_schema/01_tablas/` en orden numérico,
   del `01_rol.sql` al `12_auditoria_equipo.sql`.
3. Ejecutar `01_seed/02_datos_iniciales.sql`.
4. Instalar las funciones en este orden: `Usuario/fn_HashPassword.sql`,
   `Usuario/fn_VerificarPassword.sql`, `Usuario/fn_RolRequiereNegocio.sql`,
   `CategoriaEquipo/fn_CalcularMontoAlquiler.sql`,
   `Equipo/fn_EquipoEstaDisponible.sql` y, al final,
   `Equipo/fn_EquiposDisponibles.sql` (depende de la función anterior).
5. Instalar los procedimientos normales, ejecutando los archivos de
   `procedures/` por entidad, en este orden: Rol, MetodoPago, Negocio, Usuario,
   CategoriaEquipo, Equipo, Mantenimiento, Reserva, DetalleReserva, Pago,
   Deposito, AuditoriaEquipo y Reportes. Dentro de cada carpeta, ejecutar los
   archivos por nombre.
6. Instalar los seis procedimientos de las carpetas `transactions/`: primero
   Mantenimiento, Reserva, Pago y Equipo.
7. Instalar los triggers de Usuario y Equipo.
8. Ejecutar las pruebas numeradas de `05_tests/`.
9. Ejecutar `06_validation/01_verificar_inventario_objetos.sql`. Debe mostrar
   76 PROCEDURE, 6 FUNCTION, 2 TRIGGER y ninguna diferencia.

Los scripts de tablas son solo para una base nueva; no ejecutarlos sobre la
base existente porque las tablas ya están creadas. Funciones, procedimientos
y triggers usan `CREATE OR ALTER` y pueden volver a instalarse.

## Pruebas del API

Para la prueba de integración, preparar el usuario y el equipo con
`05_tests/pruebas_api_preparar.sql`, seguir `backend/README.md`, y limpiar al
final con `05_tests/pruebas_api_limpiar.sql`.

## Cobertura de pruebas

Las pruebas `02` a `10` cubren catálogos, funciones, autenticación, usuarios,
equipos, reservas, transacciones, reportes y triggers. El inventario SQL de
verificación es independiente de las pruebas funcionales y sirve para detectar
objetos faltantes o inesperados en `renta`.
