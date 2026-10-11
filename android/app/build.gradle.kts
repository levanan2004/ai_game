import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. android/key.properties is gitignored and written by An
// (see android/SIGNING.md). If it is absent the release build falls back to
// the debug key so `flutter run --release` keeps working; such an APK must
// NOT be published.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    val missing = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
        .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing: ${missing.joinToString()}. " +
                "See android/SIGNING.md."
        )
    }
}

// Firebase config for Android. The plugin needs android/app/google-services.json
// (downloaded from the Firebase console, see docs/ANDROID_FIREBASE.md). Without
// the file the app still builds; Firebase is then simply not available and the
// game runs as an offline guest.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "WARNING: android/app/google-services.json not found - Firebase " +
            "(sign-in, cloud save) is disabled in this build. " +
            "See docs/ANDROID_FIREBASE.md."
    )
}

android {
    namespace = "com.tiemhoasommai.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Same id must be used when adding the Android app in the Firebase
        // console (see android/SIGNING.md and docs/ANDROID_FIREBASE.md).
        applicationId = "com.tiemhoasommai.game"
        // versionName / versionCode come from `version:` in pubspec.yaml
        // (1.0.0+1 -> versionName 1.0.0, versionCode 1).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // Relative paths are resolved from android/app/.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: android/key.properties not found - the release " +
                        "build is signed with the DEBUG key. Do not publish it. " +
                        "See android/SIGNING.md."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
