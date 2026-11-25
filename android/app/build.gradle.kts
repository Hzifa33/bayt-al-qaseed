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

    flavorDimensions += "edition"
    productFlavors {
        create("standard") {
            dimension = "edition"
            applicationId = "com.baytalqaseed.app"
            manifestPlaceholders["appName"] = "بيت القصيد"
        }
        create("expanded") {
            dimension = "edition"
            applicationId = "com.baytalqaseed.expanded"
            versionCode = 2
            versionName = "2.0.0"
            manifestPlaceholders["appName"] = "بيت القصيد الموسّعة"
        }
    }

    buildTypes {
        release {
            // Deliberately left unsigned so CI outputs a clean Unsigned Release APK
            // ready for manual signing via apksigner.
            signingConfig = null
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    androidResources {
        noCompress += listOf("gz", "db")
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
