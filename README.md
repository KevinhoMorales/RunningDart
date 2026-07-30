# SAINTS Wellness Club

Aplicación móvil en Flutter para **SAINTS Wellness Club** (Santo Domingo de los Tsáchilas): membresías, credencial digital QR, beneficios con marcas aliadas, validación en punto de venta y panel administrativo.

## Descripción

SAINTS Wellness Club conecta a la comunidad runner con el club y sus aliados comerciales. Los miembros registran su modalidad (Comunidad, Miembro Oficial 2026 o Pro Team), reciben una credencial digital con QR y acceden a beneficios filtrados por modalidad. Las marcas aliadas validan membresías escaneando el QR; los administradores aprueban solicitudes, activan/desactivan roles y gestionan el catálogo.

## Modalidades y estados

| Modalidad | Rol app | Acceso | Entrenamientos |
|---|---|---|---|
| Comunidad SAINTS | `user` | Activo al registrarse | Mar/Jue 7 p.m. Jelen Tenka |
| Miembro Oficial 2026 | `member` | Pendiente hasta activación admin | Comunidad + beneficios |
| SAINTS Pro Team | `member` | Pendiente hasta activación admin | L/M/V 7 p.m. + gym/fondos |

Estados de membresía: **Pendiente** (espera aprobación admin) → **Activo** → **Inactivo** / **Vencido** (`expiresAt`, default 31-dic-2026 para Oficial).

Operador de marca aliada = `member` + `businessId` asignado por admin.

## Características principales

### Registro y membresía
- Formulario enriquecido: WhatsApp, últimos 4 dígitos de cédula, fecha de nacimiento, T&C
- Todo registro crea un usuario base (`role: user`, modalidad Comunidad, activo)
- Un admin cambia después el rol/modalidad (Oficial, Pro Team, member, etc.) desde el panel

### Credencial digital
- Tarjeta tipo wallet en perfil: nombre, modalidad, estado, vigencia, QR
- QR oculto si la membresía está pendiente, inactiva o vencida
- Comunidad no tiene credencial: la tarjeta lo dice así en lugar de mostrarse como un estado incompleto

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
- Activar/desactivar cuenta y cambiar rol (`user` / `member` / …)
- CRUD marcas aliadas, eventos/noticias, usuarios
- Cola de reportes de publicaciones: ocultar el post, resolver o descartar la denuncia

### Horarios de entrenamiento
- Pantalla estática Comunidad / Oficial / Pro Team en Jelen Tenka (`/training-schedule`)

## Ambientes (prod / dev)

Un solo proyecto Firebase con datos aislados por prefijo de ambiente:

| Recurso | Producción | Desarrollo |
|---|---|---|
| Firestore | `environments/prod/{colección}/{id}` | `environments/dev/{colección}/{id}` |
| Storage | `environments/prod/{colección}/...` | `environments/dev/{colección}/...` |
| Firebase Auth | Compartido entre flavors | Compartido entre flavors |

- **Registro / login**: el perfil Firestore se crea y consulta solo en el ambiente activo (`environments/prod/...` o `environments/dev/...`). Mismo correo en Auth puede tener perfil en prod y otro distinto en dev.
- **Firebase Console (Firestore)**: perfiles en `environments/prod/users` o `environments/dev/users`. Si el documento no existe en el ambiente del build, la app no mantiene sesión.
- **Cold start** (dev y prod): al abrir la app se consulta `environments/{env}/users/{uid}`; si no existe, sign-out y pantalla de login. En builds **dev**, el log de consola muestra la ruta consultada y si el perfil existe.
- **Auto-login al reabrir la app** (dev y prod): si Firebase Auth restaura sesión **y** existe el documento `environments/{env}/users/{uid}`, entra directo; si el perfil fue eliminado, hace sign-out y muestra login.
- **Login manual** (otro dispositivo): siempre correo + contraseña; valida que exista perfil en el ambiente activo. Si Auth es válido pero no hay perfil en ese ambiente, cierra sesión y muestra mensaje para registrarse.
- **Registro con correo ya usado en Auth**: si el correo existe en Auth pero no hay perfil en este ambiente, crea solo el documento Firestore (no duplica en el otro ambiente).
- **Storage**: fotos de perfil/posts usan `environments/prod/...` o `environments/dev/...` (misma convención que Firestore). Objetos legacy bajo `prod/` o `dev/` en la raíz del bucket no se migran.
- **Eliminar cuenta**: borra storage y perfil del ambiente activo (y datos legacy de `payments` si existen); la cuenta Auth se elimina vía Cloud Function (o fallback local en dev).

El ambiente lo manda el package/bundle id del build instalado (`*.dev` → dev, cualquier otro → prod). `APP_ENV`, que se pasa con `--dart-define-from-file=config/env/{dev|prod}.json`, es solo el respaldo para donde no hay package id (web y tests).

El orden es ese y no al revés porque `ios/Flutter/Generated.xcconfig` conserva los `DART_DEFINES` del último `flutter build` por CLI: si se compiló una vez con `--flavor dev`, un Run posterior del scheme `prod` desde Xcode arrastraba `APP_ENV=dev` y abría producción contra datos de desarrollo.

| Build | Bundle / package id | Ambiente |
|---|---|---|
| Android flavor `dev` / iOS scheme `dev` | `com.devlokos.runningdart.dev` | `dev` |
| Android flavor `prod` / iOS scheme `prod` | `com.devlokos.runningdart` | `prod` |

### Ejecutar

```bash
# Producción
flutter run --flavor prod --dart-define-from-file=config/env/prod.json

# Desarrollo
flutter run --flavor dev --dart-define-from-file=config/env/dev.json
```

| IDE | Cómo elegir ambiente |
|---|---|
| **Cursor / VS Code** | Run and Debug → `SAINTS Dev` o `SAINTS Prod` ([`.vscode/launch.json`](.vscode/launch.json)) |
| **Xcode** | Scheme `dev` o `prod` (solo existen esos dos; no uses un scheme genérico) |
| **Android Studio** | Build Variants → `devDebug` / `prodDebug` (o `*Release` / `*Profile`) |

El ambiente Firestore queda alineado con el flavor/scheme vía package/bundle id.

| Variante | Package / bundle | Ambiente |
|---|---|---|
| Android `devDebug` / iOS scheme `dev` | `com.devlokos.runningdart.dev` | `dev` |
| Android `prodDebug` / iOS scheme `prod` | `com.devlokos.runningdart` | `prod` |

Banner naranja **DEV** visible solo en desarrollo.

**Firebase Console:** el proyecto `running-dart` tiene cuatro apps registradas, dev y prod para cada plataforma. En Android cada flavor toma su `google-services.json` de `android/app/src/{dev,prod}/`. En iOS los dos `GoogleService-Info.plist` viven en `ios/config/{dev,prod}/` y una build phase del target Runner copia el que toca según el bundle id. `lib/firebase_options.dart` elige la configuración según el ambiente resuelto.

## Colecciones Firestore

Todas viven bajo `environments/{prod|dev}/`:

- **users**: perfil + `whatsapp`, `nationalIdLast4`, `birthDate`, `membershipModality`, `membershipStatus`, `expiresAt`, `activatedAt`, `internalNotes`, `acceptedTermsAt`, `qrCode`, `role`, `businessId`
- **businesses**: marcas aliadas + `whatsapp`, `instagram`, `conditions`, `allianceStatus`, `validUntil`, `applicableModalities[]`
- **visits**: validaciones QR + `validationResult`, `memberModality`, `memberStatus`, `benefitUsed`, `expiresAt`
- **news**: eventos y comunicados del club
- **posts**: publicaciones de la comunidad + `isHidden` y el detalle de moderación (`hiddenReason`, `hiddenNote`, `hiddenAt`, `hiddenBy`)
- **public_profiles** / **usernames**: perfil visible entre socios y reserva del usuario, uno por cuenta
- **follows**, **post_likes**, **blocks**: grafo social; `blocks` solo lo lee quien bloqueó
- **post_reports**: denuncias de publicaciones + `status`, que resuelve el admin desde la pestaña Reportes

Reglas: [`firestore.rules`](firestore.rules) · Storage: [`storage.rules`](storage.rules)

Publicar reglas e índices:
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Las reglas de `posts` exigen `isHidden` para poder filtrar las ocultas en el
servidor. Antes de publicarlas por primera vez hay que rellenar el campo en las
publicaciones anteriores, o desaparecen del feed:
```bash
node scripts/backfill-post-is-hidden.js --env prod          # dry-run
node scripts/backfill-post-is-hidden.js --env prod --apply
```

## Tests

```bash
flutter test
flutter test --dart-define=APP_ENV=dev test/app_environment_dev_test.dart
npm run test:rules
```

`test:rules` levanta el emulador de Firestore en un puerto propio, así que no
choca con uno que ya tengas corriendo.

## Google Play review (Android prod)

Play revisa el AAB del flavor **prod** (`com.devlokos.runningdart` → `environments/prod/...`). Auth es compartido con dev, pero el perfil Firestore no: una cuenta solo sembrada en `environments/dev/users` falla en el build de Play y deja al reviewer en login.

### Sign-in details (obligatorio)

1. Crear usuario en Firebase Auth (correo + contraseña).
2. Crear documento en `environments/prod/users/{uid}` con al menos:
   - `membershipModality: "community"`
   - `membershipStatus: "active"`
   - `role: "user"`
   - `isActive: true`
   - campos de perfil requeridos (`displayName`, `username`, etc.)
3. Pegar email/password en Play Console → **App content → App access / Sign-in details**.
4. Instrucciones para el reviewer: *“Usar Comunidad; no requiere pago. Oficial/Pro Team los activa un administrador.”*

No uses cuentas Oficial/Pro Team pendientes: pasan el login pero quedan en “Solicitud en revisión”.

### Photo / Video policy

La app usa el **Android Photo Picker** (sin `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE`). Cámara se mantiene para QR. Sube solo AAB **prod** tras cambios de permisos.

### Publicar

```bash
flutter build appbundle --flavor prod --dart-define-from-file=config/env/prod.json
```

## Instalación

1. `flutter pub get`
2. Configurar Firebase (Auth, Firestore, Storage, FCM)
3. Primer admin: en Console, `environments/prod/users/{uid}` → `role: "admin"`, `isActive: true`
4. `flutter run --flavor prod --dart-define-from-file=config/env/prod.json`

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