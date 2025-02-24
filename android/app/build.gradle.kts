plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")  // Flutter plugin
    id("com.chaquo.python")  // 🔹 Chaquopy for Python execution
}

android {
    namespace = "com.example.spotscriber_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.spotscriber_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 🔹 Chaquopy Python Configuration
        python {
            version "3.8"  // Ensure compatibility with Faster-Whisper
            pip {
                install "faster-whisper"
                install "resemblyzer"
                install "numpy"
                install "pydub"
                install "scikit-learn"
                install "torch"
                install "ctranslate2"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
