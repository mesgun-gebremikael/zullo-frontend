import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local key.properties is ignored by Git. CI may supply the matching environment
// variables instead; never fall back to Android's public development key.
val releaseProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) propertiesFile.inputStream().use { load(it) }
}
val releaseKeys = mapOf(
    "storeFile" to "ZULLO_ANDROID_KEYSTORE_PATH",
    "storePassword" to "ZULLO_ANDROID_STORE_PASSWORD",
    "keyAlias" to "ZULLO_ANDROID_KEY_ALIAS",
    "keyPassword" to "ZULLO_ANDROID_KEY_PASSWORD",
)
val releaseValues = releaseKeys.mapValues { (propertyName, environmentName) ->
    providers.environmentVariable(environmentName).orNull
        ?: releaseProperties.getProperty(propertyName)
}
val hasReleaseSigning = releaseValues.values.all { !it.isNullOrBlank() }
val releaseKeystore = releaseValues["storeFile"]?.let { rootProject.file(it) }
val validateZulloReleaseSigning = tasks.register("validateZulloReleaseSigning") {
    group = "verification"
    description = "Require owner-supplied signing credentials for release artifacts."
    doLast {
        if (!hasReleaseSigning) throw GradleException(
            "ZULLO_RELEASE_SIGNING_REQUIRED: Configure android/key.properties or the " +
                "ZULLO_ANDROID signing environment variables; see docs/ANDROID_RELEASE_SIGNING.md."
        )
        if (releaseKeystore?.isFile != true) throw GradleException(
            "ZULLO_RELEASE_KEYSTORE_MISSING: The configured keystore must be an existing file."
        )
    }
}
tasks.matching {
    it.name in setOf("assembleRelease", "bundleRelease", "packageRelease", "validateSigningRelease")
}.configureEach { dependsOn(validateZulloReleaseSigning) }

android {
    namespace = "com.example.zullo_app"
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
        applicationId = "com.example.zullo_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = releaseValues["storePassword"]
                keyAlias = releaseValues["keyAlias"]
                keyPassword = releaseValues["keyPassword"]
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
