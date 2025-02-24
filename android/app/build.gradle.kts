// ✅ Apply necessary plugins with correct versions
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ✅ Ensure correct Kotlin plugin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.chaquo.python") // ✅ Ensure Chaquopy for Python execution
}

// ✅ Configure Android settings
android {
    namespace = "com.example.spotscriber_app"
    compileSdk = 34  // ✅ Updated compile SDK for latest Android

    defaultConfig {
        applicationId = "com.example.spotscriber_app"
        minSdk = 21
        targetSdk = 34  // ✅ Updated target SDK
        versionCode = 1
        versionName = "1.0"

        python {
            version = "3.8"  // ✅ Ensure compatible Python version
            pip {
                install("faster-whisper")
                install("resemblyzer")
                install("numpy")
                install("pydub")
                install("scikit-learn")
                install("vosk")  // ✅ Add Vosk for speech recognition
            }
        }
    }

    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
            signingConfig = signingConfigs.getByName("debug")  // ✅ Keep debug signing for now
        }
    }

    // ✅ Ensure JNI libraries are included
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
            assets.srcDirs("src/main/assets", "src/main/python")
        }
    }
}

// ✅ Ensure correct dependencies are included
dependencies {
    implementation("com.android.support:multidex:1.0.3") // ✅ Multidex support for large apps
    implementation("androidx.appcompat:appcompat:1.6.1") // ✅ Ensure AppCompat dependency
    implementation("com.chaquo.python:gradle:12.0.1")  // ✅ Ensure Chaquopy dependency
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.22")  // ✅ Ensure Kotlin stdlib compatibility
}
