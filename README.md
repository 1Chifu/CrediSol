# CrediSol: app de préstamos (Flutter + Firebase)

App Android para Perú (soles, español). Tiene 2 roles:

- **Cliente:** se registra con GPS, simula préstamos (con tasa, TCEA y total a pagar), solicita en 3 pasos
  (datos, fotos de identidad con la cámara y consentimiento), ve su cronograma, paga sus cuotas por Yape, Plin o
  transferencia y recibe recordatorios.
- **Administrador** (`usuarios/{uid}.rol == "admin"`): ve el panel, los clientes con su ubicación, datos y
  fotos, aprueba o rechaza solicitudes (las cuotas se generan al aprobar) y confirma o rechaza pagos.

Flujo: Registro → Simulador → Solicitud → Aprobación → Cronograma → Reporte de pago → Confirmación.

## Ejecutar
```
flutter pub get
flutter run
flutter test
```

## Firebase (proyecto `pahecogasparjean`, plan Spark)
- Colecciones: `usuarios/{uid}` (+ `documentos/{tipo}`), `prestamos/{id}` (+ `cuotas/{nnn}`).
- Estados del préstamo: `Pendiente`, `Activo`, `Rechazado`, `Cancelado`, `Pagado`.
- Estados de la cuota: `Pendiente`, `Por verificar`, `Pagada`.
- Reglas e índices: `firestore.rules` y `firestore.indexes.json`. Publicar con `firebase deploy --only firestore`.
- Las colecciones antiguas `clientes` y `pagos` ya no se usan y están bloqueadas.

## Documentación
- `docs/publicacion.md`: lista de verificación para Google Play.
- `docs/limitaciones.md`: limitaciones conocidas.
- `docs/migracion_storage.md`: fotos en base64 y cómo pasar a Storage.
- `docs/recuperacion_contrasena.md`: enlace actual y alternativas con código (costos).

## Estructura principal (`lib/`)
| Archivo | Qué hace |
|---|---|
| `auth_gate.dart` | Decide la pantalla según la sesión y el rol |
| `cliente_shell.dart` | Pestañas del cliente: Inicio, Simular, Préstamos y Perfil |
| `cliente_inicio_screen.dart` | Próxima cuota, saldo y progreso |
| `cliente_home_screen.dart` | Simulador |
| `solicitud_screen.dart` | Solicitud en 3 pasos |
| `mis_prestamos_screen.dart` | Préstamos, cronograma, pago, cancelación y línea de tiempo |
| `perfil_screen.dart`, `historial_pagos_screen.dart` | Perfil, contraseña e historial |
| `home_screen.dart` | Pestañas del administrador |
| `dashboard_screen.dart`, `clientes_screen.dart`, `solicitudes_screen.dart`, `cobranzas_screen.dart` | Panel de administración |
| `cronograma.dart` | Sistema francés y TCEA |
| `config_prestamos.dart`, `config_pagos.dart` | Tasa, límites, datos del negocio y medios de pago |
| `recordatorios.dart` | Notificaciones locales de cuotas |

Los archivos antiguos que ya no se usan están en `obsoletos/` y quedan fuera del análisis.
