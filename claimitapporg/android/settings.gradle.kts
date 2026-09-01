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
    // 8.11.1 is the minimum the current Flutter SDK accepts. Below it, every
    // build fails at plugin-apply time with:
    //   "Your project's Android Gradle Plugin version (8.9.1) is lower than
    //    Flutter's minimum supported version of 8.11.1"
    //
    // Raising it here is the real fix; --android-skip-build-dependency-validation
    // only silenced the check. Gradle 8.14, Java 17 and Kotlin 2.2.20 in this
    // project all already satisfy what AGP 8.11.1 requires, so this is a
    // build-toolchain change only — no app code, behaviour or UI is affected.
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // FCM: Google Services plugin — reads android/app/google-services.json
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
