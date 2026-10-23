import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val local = Properties()
val localFile = rootProject.file("local.properties")
if (localFile.exists()) localFile.inputStream().use { local.load(it) }
fun prop(name: String) = (local.getProperty(name) ?: "").replace("\\", "\\\\").replace("\"", "\\\"")

val copySharedContent = tasks.register<Copy>("copySharedContent") {
    from(rootProject.file("../Unbrick/Unbrick/Resources/Content.json"))
    into(layout.buildDirectory.dir("generated/unbrick-assets"))
    rename { "content.json" }
}

android {
    namespace = "com.imexglobalintl.unbrick"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.imexglobalintl.unbrick"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "API_BASE", "\"${prop("UNBRICK_API_BASE")}\"")
        buildConfigField("String", "APP_TOKEN", "\"${prop("UNBRICK_APP_TOKEN")}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("generated/unbrick-assets"))
}

tasks.named("preBuild").configure { dependsOn(copySharedContent) }

dependencies {
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation(platform("androidx.compose:compose-bom:2024.09.02"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
