extra.set("desugar_jdk_libs_version", "2.2.0")

// Define standard SDK versions accessible to all subprojects
extra.set("compileSdkVersion", 34) // Use a modern API level
extra.set("minSdkVersion", 23)     // Use a stable minimum (e.g., API 23)
extra.set("targetSdkVersion", 34)  // Should match compileSdkVersion
extra.set("kotlin_version", "1.9.22") // Ensure Kotlin version is modern

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
