# SAINTS Wellness Club

Aplicación móvil en Flutter para **SAINTS Wellness Club** (Santo Domingo de los Tsáchilas): membresías, credencial digital QR, beneficios con marcas aliadas, validación en punto de venta y panel administrativo.

## Descripción

SAINTS Wellness Club conecta a la comunidad runner con el club y sus aliados comerciales. Los miembros registran su modalidad (Comunidad, Miembro Oficial 2026 o Pro Team), reciben una credencial digital con QR y acceden a beneficios filtrados por modalidad. Las marcas aliadas validan membresías escaneando el QR; los administradores aprueban solicitudes, registran pagos y gestionan el catálogo.

## Modalidades y estados

| Modalidad | Rol app | Pago MVP | Entrenamientos |
|---|---|---|---|
| Comunidad SAINTS | `user` | Gratis | Mar/Jue 7 p.m. Jelen Tenka |
| Miembro Oficial 2026 | `member` | USD 5 (comprobante manual) | Comunidad + beneficios |
| SAINTS Pro Team | `member` | USD 5 (comprobante manual) | L/M/V 7 p.m. + gym/fondos |

Estados de membresía: **Pendiente** (espera aprobación admin) → **Activo** → **Inactivo** / **Vencido** (`expiresAt`, default 31-dic-2026 para Oficial).

Operador de marca aliada = `member` + `businessId` asignado por admin.

## Características principales

### Registro y membresía
- Formulario enriquecido: WhatsApp, últimos 4 dígitos de cédula, fecha de nacimiento, modalidad, T&C
- Upload de comprobante (Oficial / Pro Team) → Storage `payments/{uid}/...`
- Estado **Pendiente** hasta aprobación admin; pantalla "Solicitud en revisión"

### Credencial digital
- Tarjeta tipo wallet en perfil: nombre, modalidad, estado, vigencia, QR
- QR oculto si membresía pendiente, inactiva o vencida

### Marcas aliadas y beneficios
- Catálogo con condiciones, WhatsApp, Instagram, vigencia de alianza
- Filtro de beneficios según modalidad del miembro
- **Google Maps embebido** + búsqueda Places al registrar marcas (admin)
- Navegación nativa a Google Maps / Waze / Apple Maps

### Validación QR (operador)
- Escaneo con sheet de resultado: nombre, modalidad, estado, vigencia, beneficio
- Validación de vigencia/modalidad antes de registrar
- Historial de validaciones por marca

### Admin
- Aprobar/rechazar membresías, editar modalidad, vigencia, observaciones internas
- Registrar pagos manuales e historial por usuario
- CRUD marcas aliadas, eventos/noticias, usuarios

### Horarios de entrenamiento
- Pantalla estática Comunidad / Oficial / Pro Team en Jelen Tenka (`/training-schedule`)

## Colecciones Firestore

- **users**: perfil + `whatsapp`, `nationalIdLast4`, `birthDate`, `membershipModality`, `membershipStatus`, `expiresAt`, `activatedAt`, `internalNotes`, `acceptedTermsAt`, `qrCode`, `role`, `businessId`
- **businesses**: marcas aliadas + `whatsapp`, `instagram`, `conditions`, `allianceStatus`, `validUntil`, `applicableModalities[]`
- **payments**: `userId`, `modality`, `amount`, `paidAt`, `status`, `receiptUrl`, `notes`
- **visits**: validaciones QR + `validationResult`, `memberModality`, `memberStatus`, `benefitUsed`, `expiresAt`
- **news**: eventos y comunicados del club

Reglas: [`firestore.rules`](firestore.rules) · Storage: [`storage.rules`](storage.rules)

Publicar reglas:
```bash
firebase deploy --only firestore:rules,storage
```

## Tests

```bash
flutter test
node tests/firestore.rules.test.js
```

## Instalación

1. `flutter pub get`
2. Configurar Firebase (Auth, Firestore, Storage, FCM)
3. Primer admin: en Console, `users/{uid}` → `role: "admin"`, `isActive: true`
4. `flutter run`

## Estructura relevante

```
lib/
├── models/          # user, business, payment, membership enums, visit
├── screens/
│   ├── auth/        # login, register, membership_pending
│   ├── admin/       # panel, usuarios, marcas, pagos
│   ├── business/    # marcas, detalle, escaneo, validaciones
│   ├── club/        # training_schedule
│   └── profile/     # credencial digital
├── services/        # auth, user, visit, payment, business
└── widgets/         # StatusBadge, ModalityChip, MembershipCredentialCard, ...
```

---

**SAINTS Wellness Club** — Santo Domingo de los Tsáchilas · Tu comunidad, tus beneficios.