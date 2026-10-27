# Diccionario de Datos — RentaTica

**Proyecto:** Backend API REST con SQL Server — BTI23 Bases de Datos II
**Fase:** Diseño del modelo Entidad-Relación (Revisión 1)
**Sincronizado con:** `Modelo_Entidad-Relacion_Final.drawio`

> Nota: el diagrama ER es el **modelo conceptual** y, a propósito, no repite las llaves foráneas como atributos (quedan implícitas en las relaciones). Este diccionario es el **modelo lógico/físico**: por eso sí incluye las FK explícitas, tipos de dato y restricciones — es lo que se necesita para construir el modelo relacional y el script SQL.

## Decisiones de alcance confirmadas

- **Multi-tenant**: la plataforma sirve a varios negocios de alquiler de equipo en Tamarindo, cada uno con su propio inventario, empleados y clientes atendidos.
- **Solo equipo físico** (tablas, bicicletas, buggys, carritos de golf). Tours quedan fuera del alcance.
- **Reservas anticipadas y alquiler inmediato (walk-in)** ambos soportados por el mismo flujo.
- **Roles**: Administrador (dueño/gerente de un negocio en la plataforma), Operador (empleado que atiende en mostrador), Cliente (turista que alquila).

---

## Entidades

### 1. Negocio
Representa a cada empresa de alquiler que se suscribe a la plataforma (el "tenant").

| Atributo | Tipo | Notas |
|---|---|---|
| **negocio_id** (PK) | int identity | |
| nombre | varchar(100) | NOT NULL |
| direccion | varchar(200) | |
| telefono | varchar(20) | |
| email_contacto | varchar(100) | UNIQUE |
| fecha_registro | datetime | default getdate() |
| estado | varchar(20) | CHECK ('Activo','Suspendido') |

### 2. Rol
Catálogo de roles de usuario.

| Atributo | Tipo | Notas |
|---|---|---|
| **rol_id** (PK) | int identity | |
| nombre | varchar(30) | UNIQUE — 'Administrador', 'Operador', 'Cliente' |

### 3. Usuario
Toda persona que inicia sesión: administradores y operadores pertenecen a un negocio; los clientes no pertenecen a ninguno (pueden alquilar en cualquier negocio de la plataforma).

| Atributo | Tipo | Notas |
|---|---|---|
| **usuario_id** (PK) | int identity | |
| nombre_completo | varchar(100) | NOT NULL |
| email | varchar(100) | UNIQUE, NOT NULL |
| password_hash | varchar(256) | NOT NULL |
| telefono | varchar(20) | |
| documento_identidad | varchar(30) | pasaporte o cédula (clientes extranjeros) |
| rol_id (FK → Rol) | int | NOT NULL |
| negocio_id (FK → Negocio) | int | NULL — obligatorio solo si rol = Administrador/Operador |
| fecha_creacion | datetime | default getdate() |

> **Regla de negocio (candidata a trigger):** `negocio_id` debe ser NOT NULL cuando `rol` sea Administrador u Operador, y debe ser NULL cuando el rol sea Cliente. Esto no se puede expresar con un simple CHECK porque depende de otra tabla (Rol), así que es un buen candidato para el trigger obligatorio del proyecto.

### 4. CategoriaEquipo
Tipos de equipo que cada negocio ofrece (p. ej. "Tabla de surf principiante", "Bicicleta montaña").

| Atributo | Tipo | Notas |
|---|---|---|
| **categoria_id** (PK) | int identity | |
| negocio_id (FK → Negocio) | int | NOT NULL |
| nombre | varchar(80) | NOT NULL |
| descripcion | varchar(300) | |
| tarifa_hora | decimal(10,2) | CHECK > 0 |
| tarifa_dia | decimal(10,2) | CHECK > 0 |
| monto_deposito | decimal(10,2) | CHECK >= 0 |

### 5. Equipo
Unidad física individual (cada tabla, cada bicicleta tiene su propio registro).

| Atributo | Tipo | Notas |
|---|---|---|
| **equipo_id** (PK) | int identity | |
| categoria_id (FK → CategoriaEquipo) | int | NOT NULL |
| codigo_interno | varchar(20) | UNIQUE por negocio |
| descripcion | varchar(200) | marca, color, talla, etc. |
| estado | varchar(20) | CHECK ('Disponible','Reservado','Alquilado','Mantenimiento','Averiado','Fuera de servicio') |
| notas | varchar(300) | observaciones generales del equipo |
| fecha_adquisicion | date | |

### 6. Reserva
Encabezado de una solicitud de alquiler (uno o varios equipos, anticipada o walk-in).

| Atributo | Tipo | Notas |
|---|---|---|
| **reserva_id** (PK) | int identity | |
| negocio_id (FK → Negocio) | int | NOT NULL |
| cliente_id (FK → Usuario) | int | NOT NULL, rol debe ser Cliente |
| operador_id (FK → Usuario) | int | NULL si la reserva la hizo el cliente en línea |
| tipo_reserva | varchar(20) | CHECK ('Anticipada','Walk-in') |
| fecha_reserva | datetime | default getdate() — momento en que se creó |
| fecha_inicio | datetime | NOT NULL |
| fecha_fin | datetime | NOT NULL — fin programado del alquiler |
| estado | varchar(20) | CHECK ('Pendiente','Confirmada','En curso','Completada','Cancelada') |
| monto_final | decimal(10,2) | calculado, CHECK >= 0 |

### 7. DetalleReserva
Línea de detalle: qué unidad específica de equipo está en cada reserva (entidad débil, depende de Reserva).

| Atributo | Tipo | Notas |
|---|---|---|
| **detalle_id** (PK) | int identity | |
| reserva_id (FK → Reserva) | int | NOT NULL |
| equipo_id (FK → Equipo) | int | NOT NULL |
| tarifa_aplicada | decimal(10,2) | snapshot del precio al momento de reservar |
| fecha_hora_entrega | datetime | NULL hasta que se entrega el equipo |
| fecha_hora_devolucion | datetime | NULL hasta la devolución real |
| estado_equipo_devolucion | varchar(20) | CHECK ('Bueno','Averiado','Perdido') NULL hasta devolución |

### 8. MetodoPago
Catálogo de formas de pago.

| Atributo | Tipo | Notas |
|---|---|---|
| **metodo_pago_id** (PK) | int identity | |
| nombre | varchar(30) | UNIQUE — 'Efectivo','Tarjeta','SINPE Móvil' |

### 9. Pago
Transacciones de dinero asociadas a una reserva (puede haber varios pagos parciales).

| Atributo | Tipo | Notas |
|---|---|---|
| **pago_id** (PK) | int identity | |
| reserva_id (FK → Reserva) | int | NOT NULL |
| metodo_pago_id (FK → MetodoPago) | int | NOT NULL |
| monto | decimal(10,2) | CHECK > 0 |
| fecha_pago | datetime | default getdate() |
| estado | varchar(20) | CHECK ('Completado','Reembolsado') |

> Nota: `Pago` ahora representa únicamente el cobro del alquiler. La garantía/depósito se maneja por completo en la entidad `Deposito`, que tiene su propio ciclo de vida (cobro, retención, devolución).

### 10. Deposito
Control de la garantía cobrada y su devolución al final del alquiler.

| Atributo | Tipo | Notas |
|---|---|---|
| **deposito_id** (PK) | int identity | |
| reserva_id (FK → Reserva) | int | UNIQUE, NOT NULL |
| monto_cobrado | decimal(10,2) | CHECK >= 0 |
| monto_devuelto | decimal(10,2) | NULL hasta liquidar |
| monto_retencion | decimal(10,2) | NULL si se devuelve completo; debe cumplir monto_cobrado = monto_devuelto + monto_retencion |
| fecha_devolucion | datetime | NULL hasta devolución |

### 11. Mantenimiento
Historial de mantenimiento o reparación por unidad de equipo (entidad débil, depende de Equipo).

| Atributo | Tipo | Notas |
|---|---|---|
| **mantenimiento_id** (PK) | int identity | |
| equipo_id (FK → Equipo) | int | NOT NULL |
| operador_id (FK → Usuario) | int | responsable que registra el mantenimiento |
| tipo | varchar(20) | CHECK ('Preventivo','Correctivo') |
| descripcion | varchar(300) | |
| costo | decimal(10,2) | CHECK >= 0 |
| fecha_inicio | date | NOT NULL |
| fecha_fin | date | NULL mientras sigue en mantenimiento |

### 12. AuditoriaEquipo
Bitácora automática de cambios de estado del equipo (poblada por trigger — cumple el requisito de trigger de auditoría).

| Atributo | Tipo | Notas |
|---|---|---|
| **auditoria_id** (PK) | int identity | |
| equipo_id (FK → Equipo) | int | NOT NULL |
| usuario_id (FK → Usuario) | int | quién provocó el cambio, NULL si fue automático |
| estado_anterior | varchar(20) | |
| estado_nuevo | varchar(20) | |
| fecha_hora | datetime | default getdate() |

---

## Relaciones y cardinalidad

| Relación | Cardinalidad |
|---|---|
| Negocio — Usuario (admin/operador) | 1 : N |
| Rol — Usuario | 1 : N |
| Negocio — CategoriaEquipo | 1 : N |
| CategoriaEquipo — Equipo | 1 : N |
| Usuario(Cliente) — Reserva | 1 : N |
| Usuario(Operador) — Reserva | 1 : N (0 si fue online) |
| Negocio — Reserva | 1 : N |
| Reserva — DetalleReserva | 1 : N |
| Equipo — DetalleReserva | 1 : N |
| Reserva — Pago | 1 : N |
| MetodoPago — Pago | 1 : N |
| Reserva — Deposito | 1 : 1 (0 o 1) |
| Equipo — Mantenimiento | 1 : N |
| Usuario(Operador) — Mantenimiento | 1 : N |
| Equipo — AuditoriaEquipo | 1 : N |

---

## Candidatas a stored procedures con transacción explícita

1. **usp_Reserva_Crear**: inserta Reserva + sus DetalleReserva, y actualiza `Equipo.estado` a 'Reservado' o 'Alquilado' para cada unidad — todo o nada.
2. **usp_Equipo_Devolver**: actualiza DetalleReserva (fecha y estado de devolución), actualiza `Equipo.estado` (Disponible o Mantenimiento según el estado de devolución), liquida el Depósito (`monto_devuelto`, `monto_retencion`) y cierra la Reserva — varias tablas, debe ser atómico.
3. **usp_Pago_Registrar**: inserta Pago y actualiza `Reserva.monto_final`/estado de pago — debe revertirse completo si falla cualquier paso.

Estas tres (y la lógica de auditoría del trigger) son el corazón de la justificación de transacciones explícitas que pide el entregable 3.
