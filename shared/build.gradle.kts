plugins { kotlin("multiplatform"); kotlin("plugin.serialization") }
kotlin {
    jvm()
    macosArm64 { binaries.framework { baseName = "FitCheckShared"; isStatic = true } }
    iosArm64 { binaries.framework { baseName = "FitCheckShared"; isStatic = true } }
    iosSimulatorArm64 { binaries.framework { baseName = "FitCheckShared"; isStatic = true } }
    sourceSets {
        commonMain.dependencies { implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0") }
        commonTest.dependencies { implementation(kotlin("test")) }
    }
}
