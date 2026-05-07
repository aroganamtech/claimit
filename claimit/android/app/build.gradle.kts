plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.claimit"
    // compileSdk 36 is required by androidx.activity:1.12.4, androidx.core:1.18.0,
    // and androidx.navigationevent:1.0.2 that the latest Flutter pulls in.
    compileSdk = 36
    // Use the NDK shipped with the Flutter version selected by the SDK.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Some plugins (file_picker, image_picker) need Java-8+ APIs that
        // require core library desugaring on minSdk 21.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.claimit"
        // flutter_secure_storage needs minSdk 18, file_picker needs 21.
        minSdk = flutter.minSdkVersion
        // targetSdk 35 keeps runtime-behavior on Android 15 (one short of compileSdk
        // by design — only opt in to compileSdk runtime behavior after testing).
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Replace with your own signing config for production.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            isMinifyEnabled = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
