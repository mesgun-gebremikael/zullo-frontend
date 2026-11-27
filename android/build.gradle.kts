import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.api.tasks.testing.Test
import org.gradle.api.tasks.testing.logging.TestExceptionFormat
import org.gradle.jvm.toolchain.JavaLanguageVersion
import org.gradle.jvm.toolchain.JavaToolchainService

plugins {
    id("jvm-toolchains")
}

// Compile every plugin with the same supported JDK while preserving its own
// Java/Kotlin bytecode targets. This avoids JDK21's obsolete-Java8 warnings
// without changing transitive APIs or hiding compiler diagnostics.
val java17Compiler = extensions.getByType<JavaToolchainService>().compilerFor {
    languageVersion.set(JavaLanguageVersion.of(17))
}

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
    tasks.withType<JavaCompile>().configureEach {
        javaCompiler.set(java17Compiler)
    }
    tasks.withType<Test>().configureEach {
        if (project.name == "geolocator_android") {
            // Robolectric fetches Android runtimes outside Gradle's repositories.
            // Use Maven Central's canonical endpoint, as mavenCentral() does.
            systemProperty("robolectric.dependency.repo.url", "https://repo.maven.apache.org/maven2")
            testLogging.exceptionFormat = TestExceptionFormat.FULL
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
