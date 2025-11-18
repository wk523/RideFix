// File: android.build.gradle.kts (Top-level)
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // Update to AGP 8.13.0
        classpath("com.android.tools.build:gradle:8.13.0")
        // Your existing Kotlin version is fine for now
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
