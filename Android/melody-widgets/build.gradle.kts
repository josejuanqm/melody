plugins {
    `kotlin-dsl`
    `java-gradle-plugin`
    `maven-publish`
}

repositories {
    mavenCentral()
    google()
    gradlePluginPortal()
}

dependencies {
    implementation("com.charleskorn.kaml:kaml:0.66.0")
    implementation("com.android.tools.build:gradle:8.5.0")
    implementation("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.0")
}

gradlePlugin {
    plugins {
        create("melody") {
            id = "com.melody.widgets"
            implementationClass = "com.melody.plugin.MelodyPlugin"
        }
    }
}