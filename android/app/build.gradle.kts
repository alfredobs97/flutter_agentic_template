import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.alfredobs97.flutter_agentic_template"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        // Required for the per-flavor resValue("string", "app_name", ...)
        // calls in productFlavors below.
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.alfredobs97.flutter_agentic_template"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signing: reads android/key.properties (gitignored) when present, and
    // falls back to the debug key otherwise so `flutter build apk --release`
    // works out of the box before you've set up a real keystore. See
    // docs/android-release-signing.md before shipping to a store.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasKeystoreProperties = keystorePropertiesFile.exists()
    if (hasKeystoreProperties) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties yet: sign with the debug key so
                // `flutter run --release`/`flutter build apk --release`
                // still work. Replace before shipping to a store.
                signingConfigs.getByName("debug")
            }
        }
    }

    // Two flavors, matching AppFlavor in lib/app_environment.dart. Every
    // `flutter run`/`flutter build` MUST pass --flavor <dev|prod> AND
    // --dart-define=FLAVOR=<dev|prod> with the same value — see AGENTS.md
    // → "Flavors", and use .vscode/launch.json instead of typing this by
    // hand.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue(type = "string", name = "app_name", value = "Flutter Agentic Template Dev")
        }
        create("prod") {
            dimension = "env"
            resValue(type = "string", name = "app_name", value = "Flutter Agentic Template")
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
