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
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID for Zephyr Reader
        applicationId = "com.zephyr.reader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            ndk {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            }
        }
        release {
            // Signing configuration for release build
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

flutter {
    source = "../.."
}
