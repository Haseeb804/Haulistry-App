val ndkVersionOverride = "27.3.13750724"

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }

    // Force all subprojects (including Flutter plugins) to use the installed NDK version.
    // This overrides any hardcoded ndkVersion inside plugin build.gradle files.
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            val androidBase = androidExt as? com.android.build.gradle.BaseExtension ?: return@afterEvaluate
            androidBase.ndkVersion = ndkVersionOverride
        }
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
