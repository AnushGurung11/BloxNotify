import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FCM requires google-services.json in android/app/ (manual setup step, see
// README). The plugin is only applied when the file exists so the project can
// still be built before Firebase setup.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing. android/key.properties is local-only (gitignored); CI
// provides the same values via secrets. Falls back to debug signing when
// neither is present so the project always builds.
val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyProps.load(FileInputStream(keyPropsFile))
}

val releaseStoreFile = System.getenv("ANDROID_STORE_FILE") ?: keyProps.getProperty("storeFile")
val releaseStorePassword = System.getenv("ANDROID_STORE_PASSWORD") ?: keyProps.getProperty("storePassword")
val releaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: keyProps.getProperty("keyAlias")
val releaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: keyProps.getProperty("keyPassword")
val resolvedStoreFile = releaseStoreFile?.let { file(it) }

android {
    namespace = "com.bloxnotify.blox_notify"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.bloxnotify.blox_notify"
        // firebase_messaging and flutter_local_notifications require API 23+.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (resolvedStoreFile != null && releaseStorePassword != null &&
                releaseKeyAlias != null && releaseKeyPassword != null
            ) {
                signingConfig = signingConfigs.create("release") {
                    keyAlias = releaseKeyAlias
                    keyPassword = releaseKeyPassword
                    storeFile = resolvedStoreFile
                    storePassword = releaseStorePassword
                }
            } else {
                // No keystore configured (no key.properties, no CI secrets) —
                // fall back to debug signing so builds still succeed.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
