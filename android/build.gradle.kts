// ✅ Apply necessary plugins with correct versions
plugins {
    id("com.android.application") version "8.7.0" apply false  // ✅ Ensure Gradle version matches
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false  // ✅ Ensure Kotlin version matches
    id("com.chaquo.python")  // ✅ Chaquopy for Python support
}

// ✅ Configure Android settings
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
                install("vosk")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ✅ Ensure correct repository settings for Chaquopy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://chaquo.com/maven") }  // ✅ Chaquopy Repository
    }
}

// ✅ Fix Gradle build directory structure
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Ensure a clean build task is registered
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ✅ Fix Gradle dependencies
buildscript {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://chaquo.com/maven") }  // ✅ Ensure Chaquopy repository is included
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.7.0")   // ✅ Updated Gradle version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22")  // ✅ Ensure Kotlin compatibility
        classpath("com.chaquo.python:gradle:12.0.1")        // ✅ Chaquopy dependency for Python
    }
}
