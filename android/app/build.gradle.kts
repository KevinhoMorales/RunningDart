import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.devlokos.runningdart"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.devlokos.runningdart"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "SAINTS Dev")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "SAINTS")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

val appEnvDartDefine: (String) -> String = { value ->
    Base64.getEncoder().encodeToString("APP_ENV=$value".toByteArray())
}

afterEvaluate {
    tasks.withType<com.flutter.gradle.tasks.FlutterTask>().configureEach {
        val envValue = when (flavor) {
            "dev" -> "dev"
            else -> "prod"
        }
        val appEnvDefine = appEnvDartDefine(envValue)
        val existing = dartDefines
            ?.split(",")
            ?.filter { it.isNotBlank() }
            ?: emptyList()
        if (!existing.contains(appEnvDefine)) {
            dartDefines = (existing + appEnvDefine).joinToString(",")
        }
    }
}
