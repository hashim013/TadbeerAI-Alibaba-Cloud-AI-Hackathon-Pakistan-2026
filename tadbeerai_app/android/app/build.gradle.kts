plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.tadbeerai"
    compileSdk = 36
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
        applicationId = "com.example.tadbeerai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("tadbeerai2Debug") {
            storeFile = file("tadbeerai2-debug.keystore")
            storePassword = providers.gradleProperty("TADBEER_DEBUG_STORE_PASSWORD")
                .orElse(providers.environmentVariable("TADBEER_DEBUG_STORE_PASSWORD"))
                .orNull
            keyAlias = "tadbeerai2"
            keyPassword = providers.gradleProperty("TADBEER_DEBUG_KEY_PASSWORD")
                .orElse(providers.environmentVariable("TADBEER_DEBUG_KEY_PASSWORD"))
                .orNull
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("tadbeerai2Debug")
        }

        release {
            // Keep current release behavior unchanged for now.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
