plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.chaquo.python") // ✅ Ensure Chaquopy is included for running Python
}

android {
    namespace = "com.example.spotscriber_app"
    compileSdk = 33

    defaultConfig {
        applicationId = "com.example.spotscriber_app"
        minSdk = 21
        targetSdk = 33
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
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
