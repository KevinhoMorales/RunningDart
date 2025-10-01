# RunningDart

Una aplicación móvil desarrollada en Flutter que conecta usuarios con negocios locales a través de un sistema de convenios y membresías.

## 📱 Descripción

RunningDart es una aplicación que facilita la conexión entre usuarios y negocios locales que han establecido convenios con la plataforma. Los usuarios pueden descubrir establecimientos afiliados, acceder a beneficios exclusivos y mantener un perfil personal con un código QR único para verificación de membresía.

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
   - Configurar Cloud Messaging
   - Descargar `google-services.json` (Android) y `GoogleService-Info.plist` (iOS)

4. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

## 📱 Funcionalidades Detalladas

### Flujo de Usuario

1. **Registro/Inicio de sesión**
   - El usuario se registra con email y contraseña
   - Verificación de email (opcional)
   - Inicio de sesión seguro

2. **Exploración de Negocios**
   - Visualización de lista de negocios afiliados
   - Filtros por categoría, ubicación, etc.
   - Información detallada de cada establecimiento

3. **Perfil y Código QR**
   - Generación automática de código QR único
   - Código asociado al ID de usuario en Firestore
   - Escaneo para verificación en establecimientos

4. **Notificaciones**
   - Recepción de notificaciones push
   - Configuración de preferencias de notificación

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

- Autenticación segura con Firebase
- Códigos QR únicos e irrepetibles
- Validación de permisos en cada operación
- Encriptación de datos sensibles
- Cumplimiento con políticas de privacidad

## 📊 Base de Datos

### Colecciones de Firestore

- **users**: Información de usuarios registrados
- **businesses**: Catálogo de negocios afiliados
- **visits**: Registro de visitas de usuarios a negocios
- **notifications**: Historial de notificaciones enviadas

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

**RunningDart** - Conectando usuarios con negocios locales a través de la tecnología.