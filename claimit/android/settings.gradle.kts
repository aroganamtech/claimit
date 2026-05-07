pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.9.1 is the minimum required by the androidx.* dependencies pulled
    // in transitively by recent Flutter SDKs (androidx.activity:1.12.4,
    // androidx.core:1.18.0, androidx.navigationevent:1.0.2).
    id("com.android.application") version "8.9.1" apply false
    // Kotlin 1.9.24 is the highest 1.9.x; pairs cleanly with AGP 8.9.x and the
    // current Flutter Gradle plugin without triggering the AGP-9 DSL warning.
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")
