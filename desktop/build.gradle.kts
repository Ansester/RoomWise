plugins { kotlin("jvm"); kotlin("plugin.serialization"); id("org.jetbrains.compose"); id("org.jetbrains.kotlin.plugin.compose") }
dependencies {
    implementation(project(":shared"))
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")
    implementation("ai.koog:koog-agents:1.2.0")
    testImplementation(kotlin("test"))
    testImplementation(compose.desktop.uiTestJUnit4)
}
compose.desktop { application { mainClass = "fitcheck.MainKt"; jvmArgs += "--enable-native-access=ALL-UNNAMED" } }
