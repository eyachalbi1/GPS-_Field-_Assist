import groovy.lang.GroovyObject

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

subprojects {
    plugins.withId("com.android.library") {
        val androidExtension = extensions.findByName("android")
        if (androidExtension is GroovyObject) {
            val namespace = androidExtension.getProperty("namespace") as String?
            if (namespace.isNullOrBlank()) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                val manifestPackage = if (manifestFile.exists()) {
                    Regex("""package\s*=\s*"([^"]+)"""")
                        .find(manifestFile.readText())
                        ?.groupValues
                        ?.getOrNull(1)
                } else {
                    null
                }
                androidExtension.setProperty(
                    "namespace",
                    manifestPackage ?: "com.autogen.${project.name.replace("-", "_")}"
                )
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
