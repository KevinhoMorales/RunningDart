# SAINTS

Una aplicación móvil desarrollada en Flutter que conecta usuarios con negocios locales a través de un sistema de convenios y membresías.

## 📱 Descripción

SAINTS es una aplicación que facilita la conexión entre usuarios y negocios locales que han establecido convenios con la plataforma. Los usuarios pueden descubrir establecimientos afiliados, acceder a beneficios exclusivos y mantener un perfil personal con un código QR único para verificación de membresía.

## ✨ Características Principales

### 🔐 Autenticación y Seguridad
- **Inicio de sesión seguro** con Firebase Authentication
- Manejo seguro de credenciales de usuario
- Verificación de identidad mediante email/teléfono

### 🏪 Directorio de Negocios
- **Lista completa de negocios afiliados** con convenios activos
- Información detallada de cada establecimiento:
  - Nombre y descripción
  - Dirección y contacto
  - Horarios de atención
  - Servicios o productos ofrecidos
  - Beneficios exclusivos para miembros

### 👤 Perfil de Usuario
- **Código QR único** generado automáticamente para cada usuario
- Verificación instantánea de membresía en establecimientos
- Información personal del usuario
- Historial de visitas y beneficios utilizados

### 🔔 Notificaciones
- **Sistema de notificaciones push** para:
  - Nuevos negocios afiliados
  - Ofertas y promociones especiales
  - Recordatorios de membresía
  - Actualizaciones de la aplicación

## 🛠️ Tecnologías Utilizadas

### Frontend
- **Flutter** - Framework de desarrollo multiplataforma
- **Dart** - Lenguaje de programación principal

### Backend y Servicios
- **Firebase Authentication** - Autenticación de usuarios
- **Cloud Firestore** - Base de datos NoSQL para usuarios y negocios
- **Firebase Cloud Messaging** - Sistema de notificaciones push
- **Firebase Storage** - Almacenamiento de imágenes y archivos

## 🚀 Instalación y Configuración

### Prerrequisitos
- Flutter SDK (versión 3.0 o superior)
- Dart SDK
- Android Studio / Xcode para desarrollo móvil
- Cuenta de Firebase configurada

### Pasos de instalación

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/tu-usuario/RunningDart.git
   cd RunningDart
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar Firebase**
   - Crear un proyecto en [Firebase Console](https://console.firebase.google.com/)
   - Configurar Authentication con email/password
   - Configurar Firestore Database
   - Configurar Firebase Storage
   - **Publicar reglas de seguridad** (obligatorio para que funcione el registro):
     ```bash
     firebase deploy --only firestore:rules,storage
     ```
     O copiar y publicar manualmente en Console el contenido de [`firestore.rules`](firestore.rules) y [`storage.rules`](storage.rules)
   - **Firebase Cloud Messaging (push):**
     - En Firebase Console → Project settings → Cloud Messaging, habilita la API
     - **iOS:** sube la clave APNs (.p8) en Cloud Messaging; en Xcode activa **Push Notifications** y **Background Modes → Remote notifications** (ya configurado en el repo)
     - **Android:** el permiso `POST_NOTIFICATIONS` y el canal `saints_alerts` ya están en el manifest
     - Instala dependencias de Functions y despliega (requiere plan **Blaze**):
       ```bash
       cd functions && npm install && cd ..
       firebase deploy --only functions
       ```
     - Los usuarios activos se suscriben a los topics `saints_new_businesses` y `saints_new_events` al iniciar sesión; pueden desactivarlos en **Ajustes**
   - Descargar `google-services.json` (Android) y `GoogleService-Info.plist` (iOS)

4. **Roles y administración**
   - **Membresía** (`role`): `"user"`, `"member"` o `"admin"` en Firestore (`users/{uid}`)
   - **Operación de negocio** (`businessId` opcional): si está asignado, el usuario puede escanear QR e ver visitas
   - Los nuevos registros quedan con `role: "user"` e `isActive: true` y entran directo a **Home**
   - Experiencias (con cuenta activa):
     - **user** (sin `businessId`): explora negocios con información básica
     - **member** (sin `businessId`): beneficios, descuentos y código QR en perfil
     - **miembro operador** (`member` + `businessId`): escaneo, visitas, catálogo y perfil con QR — tabs **Escanear · Visitas · Negocios · Perfil**
     - **admin**: panel admin (Negocios · Perfil · Usuarios) + crear/editar negocios
   - **Flujo operador de negocio:**
     1. Admin crea el negocio (FAB en tab Negocios o `/admin/businesses/new`)
     2. Admin asigna `businessId` al usuario en detalle de usuario (si era `user`, pasa a `member` automáticamente)
     3. El operador usa tabs **Escanear**, **Visitas**, **Negocios** y **Perfil**
   - **Restricciones de escaneo:** el operador conserva QR y beneficios de miembro, pero **no puede** registrar visitas escaneando su propio código ni el de otro operador del mismo negocio; solo miembros **externos** generan visitas válidas
   - Usuarios legacy con `role: "business"` se interpretan como `member` (conservando `businessId`)
   - Para el **primer admin** en Console: `users/{uid}` → `role: "admin"`, `isActive: true`

5. **Registro y foto de perfil**
   - Tras registrarse, el usuario llega a **Home** como **Usuario**
   - Firestore crea `users/{uid}` con: `email`, `displayName`, `qrCode`, `createdAt`, `isActive`, `role`
   - La foto es **opcional**; se sube después desde **Perfil** (ícono de cámara)
   - Si `isActive` es `false`, el usuario ve **Cuenta desactivada**
   - Si un registro falló antes (usuario huérfano en Auth), bórralo en Authentication e intenta de nuevo

6. **Panel admin en la app**
   - Tab **Usuarios**: listar, buscar, activar/desactivar, cambiar rol y asignar `businessId`
   - Tab **Negocios** (FAB): crear negocios con foto, descuento, beneficios y datos de contacto
   - Tab **Noticias** (FAB): crear y publicar eventos de SAINTS (título, resumen, fecha, lugar, foto)
   - Tab **Admin**: gestionar **Usuarios**, **Eventos** (incl. finalizados) y **Negocios**; eliminar eventos y negocios con **doble confirmación + Face ID/huella**
   - Los eventos pasados **no aparecen** en el tab Noticias público; muestran badge de estatus (*Hoy*, *En X días*, *En 1 semana*, etc.)
   - Publicar reglas: `firebase deploy --only firestore:rules,storage`

7. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

## 📱 Funcionalidades Detalladas

### Flujo de Usuario

1. **Registro/Inicio de sesión**
   - El usuario se registra con email y contraseña (sin foto obligatoria)
   - Tras el registro entra directamente a **Home** con rol **Usuario** (`role: user`)
   - Se crea el documento `users/{uid}` en Firestore con:
     - `email`, `displayName`, `qrCode`, `createdAt`, `isActive: true`, `role: "user"`
     - `photoUrl` solo si el usuario sube foto después desde **Perfil**
   - Inicio de sesión seguro con Firebase Auth
   - Cuentas desactivadas (`isActive: false`) no pueden usar la app

2. **Exploración de Negocios**
   - Visualización de lista de negocios afiliados
   - Filtros por categoría
   - Información detallada de cada establecimiento
   - Usuarios con rol **member** o **admin** ven beneficios exclusivos

3. **Perfil y Código QR**
   - Foto de perfil **opcional**; se edita desde **Perfil** (ícono de cámara)
   - Imagen almacenada en Firebase Storage (`users/{uid}/profile.jpg`)
   - URL de la foto guardada en Firestore como `photoUrl`
   - Código QR y membresía disponibles solo para **member** y **admin**
   - Usuarios con rol **user** ven perfil básico y mensaje para solicitar membresía

4. **Notificaciones**
   - Push automáticas cuando un admin crea un **negocio** o publica un **evento**
   - Cloud Functions envían a topics FCM; la app muestra la alerta y abre el detalle al tocar
   - Preferencia on/off en **Ajustes → Notificaciones**

### Para Negocios Afiliados

- Verificación de membresía mediante escaneo de QR
- Acceso a información del usuario (con permisos)
- Registro de visitas y beneficios utilizados

## 🔧 Estructura del Proyecto

```
lib/
├── main.dart
├── models/
│   ├── user_model.dart
│   ├── business_model.dart
│   └── notification_model.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── business/
│   │   ├── business_list_screen.dart
│   │   └── business_detail_screen.dart
│   ├── profile/
│   │   └── profile_screen.dart
│   └── home/
│       └── home_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── notification_service.dart
│   └── qr_service.dart
├── widgets/
│   ├── business_card.dart
│   ├── qr_generator.dart
│   └── custom_app_bar.dart
└── utils/
    ├── constants.dart
    └── helpers.dart
```

## 🔐 Seguridad

Reglas básicas actuales (publicar en Firebase Console):

**Firestore** ([`firestore.rules`](firestore.rules)):
- `users/{uid}`: owner lee/edita su doc (sin cambiar rol/estado); admin lee/actualiza todos; operador (`businessId`) lee miembros activos
- Registro permitido con `role: "user"` e `isActive: true`
- `businesses`: lectura autenticada; create/update/delete solo admin
- `news`: lectura autenticada de publicados (`isPublished: true`); admin lee/escribe/elimina todos
- `visits`: create solo operador con `businessId`; read operador (su negocio) o admin

**Storage** ([`storage.rules`](storage.rules)):
- `users/{uid}/profile.jpg`: lectura autenticada; escritura solo el dueño (máx. 5 MB, imagen)
- `businesses/{businessId}/cover.jpg`: lectura autenticada; escritura solo admin
- `news/{newsId}/cover.jpg`: lectura autenticada; escritura solo admin

La **Firebase Console** puede editar cualquier documento sin estas restricciones (admin manual).

- Autenticación segura con Firebase
- Códigos QR únicos e irrepetibles

## 📊 Base de Datos

### Colecciones de Firestore

- **users**: Perfil (`email`, `displayName`, `qrCode`, `createdAt`, `isActive`, `role`, `businessId` opcional, `photoUrl` opcional)
- **news**: Eventos SAINTS (`title`, `summary`, `body`, `eventDate`, `location` opcional, `imageUrl` opcional, `isPublished`, `createdAt`, `updatedAt`). Solo eventos publicados con `eventDate >= hoy` en el tab Noticias público (filtro en cliente).
- **businesses**: Catálogo (`name`, `description`, `address`, `phone`, `hours`, `category`, `benefits`, `discount`, `imageUrl` opcional)
- **visits**: Escaneos QR (`userId`, `businessId`, `visitedAt`, `memberDisplayName`, `memberQrCode`, `scannedByUserId`)

### Cloud Functions

- **`onBusinessCreated`**: push al topic `saints_new_businesses` cuando se crea `businesses/{id}`
- **`onNewsCreated`**: push al topic `saints_new_events` si el evento se crea publicado
- **`onNewsPublished`**: push al publicar un borrador (`isPublished` pasa a `true`)

## 🚀 Próximas Características

- [ ] Sistema de reseñas y calificaciones
- [ ] Mapa interactivo con ubicación de negocios
- [ ] Programa de lealtad y puntos
- [ ] Chat con negocios afiliados
- [ ] Reservas y citas
- [ ] Integración con sistemas de pago
- [ ] Análisis de datos y estadísticas

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 📞 Contacto

- **Desarrollador**: [Tu Nombre]
- **Email**: [tu-email@ejemplo.com]
- **Proyecto**: [https://github.com/tu-usuario/RunningDart](https://github.com/tu-usuario/RunningDart)

---

**SAINTS** - Tu comunidad, tus beneficios exclusivos.