plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.baytalqaseed.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.baytalqaseed.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "بيت القصيد"
    }

    buildTypes {
        release {
            // Deliberately left unsigned so CI outputs a clean Unsigned Release APK
            // ready for 16 KB page-aligned zipalign + apksigner signing.
            signingConfig = null
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            // Required for Android 15 (API 35) 16 KB page-size direct mmap compatibility.
            useLegacyPackaging = false
            // Strip desktop emulator ABIs bundled by third-party AARs (e.g. sqlite3_flutter_libs).
            excludes += listOf("**/x86/**", "**/x86_64/**")
        }
    }

    androidResources {
        noCompress += listOf("xz", "gz", "db")
    }
}

dependencies {
    // Pure-Java XZ/LZMA2 streaming decompressor (zero native .so libs, ~110 KB).
    implementation("org.tukaani:xz:1.10")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
