import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "cl.urcalab.chao600"
    compileSdk = 36

    defaultConfig {
        applicationId = "cl.urcalab.chao600"
        // CallScreeningService and the call-screening role arrive with Android 10.
        minSdk = 29
        targetSdk = 36
        versionCode = 2
        versionName = "1.0"
    }

    // Upload key for Play Store: copy keystore.properties.example to keystore.properties.
    val keystoreFile = rootProject.file("keystore.properties")
    val signing = if (keystoreFile.exists()) {
        signingConfigs.create("release") {
            val props = Properties().apply { keystoreFile.inputStream().use(::load) }
            storeFile = rootProject.file(props.getProperty("storeFile"))
            storePassword = props.getProperty("storePassword")
            keyAlias = props.getProperty("keyAlias")
            keyPassword = props.getProperty("keyPassword")
        }
    } else {
        null
    }

    buildTypes {
        release {
            signingConfig = signing
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation")

    testImplementation("junit:junit:4.13.2")
}
