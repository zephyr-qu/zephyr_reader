plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    defaultConfig {
        // Application ID for Zephyr Reader
        applicationId = "com.zephyr.reader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            ndk {
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
        }
        release {
            ndk {
                abiFilters += listOf("arm64-v8a")
            }
            // Note: Replace with your own keystore and credentials for production
            signingConfig = signingConfigs.getByName("debug")
            // TODO: Configure production signing
            // signingConfig = signingConfigs.getByName("release")
        }
    }

    signingConfigs {
        create("release") {
            // Use debug signing for now, replace with production keystore
            // storeFile = file("release-key.keystore")
            // storePassword = "your-password"
            // keyAlias = "your-alias"
            // keyPassword = "your-key-password"
        }
    }
}
//kotlin {
//    compilerOptions {
//        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
//    }
//}
flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
