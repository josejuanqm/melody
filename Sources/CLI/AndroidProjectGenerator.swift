import Foundation

/// Generates a complete Android/Gradle project structure for a Melody project.
struct AndroidProjectGenerator {

    static func generate(name: String, bundleId: String, projectDir: String, melodyVersion: String) throws {
        let fm = FileManager.default

        let androidDir = (projectDir as NSString).appendingPathComponent("android")
        let appDir = (androidDir as NSString).appendingPathComponent("app")
        let srcMainDir = (appDir as NSString).appendingPathComponent("src/main")
        let packagePath = bundleId.replacingOccurrences(of: ".", with: "/")
        let javaDir = (srcMainDir as NSString).appendingPathComponent("java/\(packagePath)")
        let resDir = (srcMainDir as NSString).appendingPathComponent("res/values")
        let gradleWrapperDir = (androidDir as NSString).appendingPathComponent("gradle/wrapper")
        let gradleLibsDir = (androidDir as NSString).appendingPathComponent("gradle")

        for dir in [androidDir, appDir, srcMainDir, javaDir, resDir, gradleWrapperDir] {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        // Write gradlew scripts (generated inline, no external dependency)
        let gradlewPath = (androidDir as NSString).appendingPathComponent("gradlew")
        try generateGradlew().write(toFile: gradlewPath, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: gradlewPath)

        try generateGradlewBat()
            .write(toFile: (androidDir as NSString).appendingPathComponent("gradlew.bat"),
                   atomically: true, encoding: .utf8)

        // Copy gradle-wrapper.jar from bundled resources
        guard let jarURL = Bundle.module.url(forResource: "gradle-wrapper", withExtension: "jar", subdirectory: "Resources") else {
            throw NSError(domain: "AndroidProjectGenerator", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "gradle-wrapper.jar not found in CLI resources bundle"])
        }
        try fm.copyItem(at: jarURL, to: URL(fileURLWithPath: (gradleWrapperDir as NSString).appendingPathComponent("gradle-wrapper.jar")))

        try generateGradleWrapperProperties()
            .write(toFile: (gradleWrapperDir as NSString).appendingPathComponent("gradle-wrapper.properties"),
                   atomically: true, encoding: .utf8)

        try generateLibsVersionsToml()
            .write(toFile: (gradleLibsDir as NSString).appendingPathComponent("libs.versions.toml"),
                   atomically: true, encoding: .utf8)

        try generateRootBuildGradle()
            .write(toFile: (androidDir as NSString).appendingPathComponent("build.gradle.kts"),
                   atomically: true, encoding: .utf8)
        try generateSettingsGradle(name: name)
            .write(toFile: (androidDir as NSString).appendingPathComponent("settings.gradle.kts"),
                   atomically: true, encoding: .utf8)
        try generateGradleProperties()
            .write(toFile: (androidDir as NSString).appendingPathComponent("gradle.properties"),
                   atomically: true, encoding: .utf8)
        try generateAppBuildGradle(bundleId: bundleId, melodyVersion: melodyVersion)
            .write(toFile: (appDir as NSString).appendingPathComponent("build.gradle.kts"),
                   atomically: true, encoding: .utf8)
        try generateAndroidManifest()
            .write(toFile: (srcMainDir as NSString).appendingPathComponent("AndroidManifest.xml"),
                   atomically: true, encoding: .utf8)
        try generateMainActivity(bundleId: bundleId)
            .write(toFile: (javaDir as NSString).appendingPathComponent("MainActivity.kt"),
                   atomically: true, encoding: .utf8)
        try generateThemes()
            .write(toFile: (resDir as NSString).appendingPathComponent("themes.xml"),
                   atomically: true, encoding: .utf8)
    }

    // MARK: - Templates

    private static func generateRootBuildGradle() -> String {
        return """
        plugins {
            alias(libs.plugins.android.application) apply false
            alias(libs.plugins.android.library) apply false
            alias(libs.plugins.kotlin.android) apply false
            alias(libs.plugins.kotlin.serialization) apply false
            alias(libs.plugins.kotlin.compose) apply false
        }
        """
    }

    private static func generateSettingsGradle(name: String) -> String {
        return """
        pluginManagement {
            repositories {
                google()
                mavenCentral()
                gradlePluginPortal()
            }
        }

        dependencyResolutionManagement {
            repositories {
                google()
                mavenCentral()
                maven { url = uri("https://jitpack.io") }
            }
        }

        rootProject.name = "\(name)"
        include(":app")
        """
    }

    private static func generateGradleProperties() -> String {
        return """
        org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
        android.useAndroidX=true
        kotlin.code.style=official
        android.nonTransitiveRClass=true
        """
    }

    private static func generateAppBuildGradle(bundleId: String, melodyVersion: String) -> String {
        return """
        import java.awt.RenderingHints
        import java.awt.image.BufferedImage
        import javax.imageio.ImageIO

        plugins {
            alias(libs.plugins.android.application)
            alias(libs.plugins.kotlin.android)
            alias(libs.plugins.kotlin.compose)
        }

        // Parse app manifest from app.yaml
        val appYaml = file("../../app.yaml")
        val appYamlText = if (appYaml.exists()) appYaml.readText() else null
        val appName = appYamlText?.let {
            Regex(\"\"\"^\\s*name:\\s*"?([^"\\n]+)"?\"\"\", RegexOption.MULTILINE)
                .find(it)?.groupValues?.get(1)?.trim()
        } ?: "Melody"
        val appId = appYamlText?.let {
            Regex(\"\"\"^\\s*id:\\s*"?([^"\\n]+)"?\"\"\", RegexOption.MULTILINE)
                .find(it)?.groupValues?.get(1)?.trim()
        } ?: "\(bundleId)"

        // Sync project YAML/Lua/icon files into build dir to avoid circular dependency
        // (pointing assets.srcDirs at the project root would include the build output dir)
        val melodyAssetsDir = layout.buildDirectory.dir("melody-assets")

        val syncMelodyAssets by tasks.registering(Sync::class) {
            from("../../") {
                include("**/*.yaml", "**/*.lua", "icon.png", "assets/**")
                exclude("android/**")
            }
            into(melodyAssetsDir)
        }

        android {
            namespace = "\(bundleId)"
            compileSdk = 35

            defaultConfig {
                applicationId = appId
                minSdk = 26
                targetSdk = 35
                versionCode = 1
                versionName = "1.0"

                resValue("string", "app_name", appName)
            }

            sourceSets {
                getByName("main") {
                    assets.srcDir(melodyAssetsDir)
                }
            }

            buildFeatures {
                compose = true
            }

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            kotlinOptions {
                jvmTarget = "17"
            }
        }

        // Generate mipmap launcher icons from icon.png
        val generateAppIcon by tasks.registering {
            val iconFile = file("../../icon.png")
            val resDir = file("src/main/res")

            inputs.file(iconFile).optional()
            outputs.dir(resDir)

            doLast {
                if (!iconFile.exists()) {
                    logger.warn("icon.png not found at ${iconFile.absolutePath}, skipping icon generation")
                    return@doLast
                }

                val sizes = mapOf(
                    "mipmap-mdpi" to 48,
                    "mipmap-hdpi" to 72,
                    "mipmap-xhdpi" to 96,
                    "mipmap-xxhdpi" to 144,
                    "mipmap-xxxhdpi" to 192
                )

                val original = ImageIO.read(iconFile)

                for ((dirName, size) in sizes) {
                    val outDir = File(resDir, dirName)
                    outDir.mkdirs()
                    val scaled = BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB)
                    val g = scaled.createGraphics()
                    g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC)
                    g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
                    g.drawImage(original, 0, 0, size, size, null)
                    g.dispose()
                    ImageIO.write(scaled, "PNG", File(outDir, "ic_launcher.png"))
                }

                logger.lifecycle("Generated launcher icons from ${iconFile.name}")
            }
        }

        tasks.named("preBuild") {
            dependsOn(generateAppIcon, syncMelodyAssets)
        }

        dependencies {
            implementation("com.github.josejuanqm.melody:melody-runtime:\(melodyVersion)")

            implementation(libs.core.ktx)
            implementation(libs.activity.compose)
            implementation(platform(libs.compose.bom))
            implementation(libs.compose.ui)
            implementation(libs.compose.material3)
        }
        """
    }

    private static func generateAndroidManifest() -> String {
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <manifest xmlns:android="http://schemas.android.com/apk/res/android">

            <uses-permission android:name="android.permission.INTERNET" />

            <application
                android:allowBackup="true"
                android:icon="@mipmap/ic_launcher"
                android:label="@string/app_name"
                android:supportsRtl="true"
                android:theme="@style/Theme.Melody"
                android:usesCleartextTraffic="true">
                <activity
                    android:name=".MainActivity"
                    android:exported="true"
                    android:configChanges="orientation|screenSize|screenLayout|smallestScreenSize|density"
                    android:theme="@style/Theme.Melody">
                    <intent-filter>
                        <action android:name="android.intent.action.MAIN" />
                        <category android:name="android.intent.category.LAUNCHER" />
                    </intent-filter>
                </activity>
            </application>

        </manifest>
        """
    }

    private static func generateMainActivity(bundleId: String) -> String {
        return """
        package \(bundleId)

        import android.graphics.BitmapFactory
        import android.os.Bundle
        import android.util.Log
        import androidx.activity.ComponentActivity
        import androidx.activity.compose.setContent
        import androidx.activity.enableEdgeToEdge
        import androidx.compose.foundation.Image
        import androidx.compose.foundation.layout.*
        import androidx.compose.foundation.shape.RoundedCornerShape
        import androidx.compose.material3.*
        import androidx.compose.runtime.*
        import androidx.compose.ui.Alignment
        import androidx.compose.ui.Modifier
        import androidx.compose.ui.draw.clip
        import androidx.compose.ui.graphics.asImageBitmap
        import androidx.compose.ui.platform.LocalContext
        import androidx.compose.ui.unit.dp
        import com.melody.core.parser.AppParser
        import com.melody.core.schema.AppDefinition
        import com.melody.runtime.plugin.MelodyPlugin
        import com.melody.runtime.renderer.MelodyApp

        /** Plugins registered for this app. Replaced by generated code when plugins are installed. */
        private val melodyPlugins: List<MelodyPlugin> = emptyList()

        class MainActivity : ComponentActivity() {
            override fun onCreate(savedInstanceState: Bundle?) {
                super.onCreate(savedInstanceState)
                enableEdgeToEdge()

                setContent {
                    var appDefinition by remember { mutableStateOf<AppDefinition?>(null) }
                    var error by remember { mutableStateOf<String?>(null) }

                    LaunchedEffect(Unit) {
                        try {
                            val parser = AppParser()
                            appDefinition = parser.parseFromAssets(this@MainActivity)
                        } catch (e: Exception) {
                            Log.e("Melody", "Failed to load app", e)
                            error = e.message ?: "Unknown error"
                        }
                    }

                    MaterialTheme {
                        Surface(
                            modifier = Modifier.fillMaxSize(),
                            color = MaterialTheme.colorScheme.background
                        ) {
                            when {
                                appDefinition != null -> MelodyApp(
                                    appDefinition = appDefinition!!,
                                    context = this@MainActivity,
                                    plugins = melodyPlugins
                                )
                                error != null -> ErrorView(error!!)
                                else -> SplashView()
                            }
                        }
                    }
                }
            }
        }

        @Composable
        private fun SplashView() {
            val context = LocalContext.current
            val iconBitmap = remember {
                try {
                    context.assets.open("icon.png").use { stream ->
                        BitmapFactory.decodeStream(stream)
                    }
                } catch (e: Exception) {
                    null
                }
            }

            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                if (iconBitmap != null) {
                    Image(
                        bitmap = iconBitmap.asImageBitmap(),
                        contentDescription = "App Icon",
                        modifier = Modifier
                            .size(120.dp)
                            .clip(RoundedCornerShape(27.dp))
                    )
                }
            }
        }

        @Composable
        private fun ErrorView(message: String) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(32.dp)
                ) {
                    Text(
                        text = "Failed to load app",
                        style = MaterialTheme.typography.titleLarge
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
        """
    }

    private static func generateThemes() -> String {
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
            <style name="Theme.Melody" parent="android:Theme.Material.Light.NoActionBar" />
        </resources>
        """
    }

    // MARK: - Gradle Wrapper

    private static func generateGradlew() -> String {
        return "#!/bin/sh\n" + ##"""
        #
        # Copyright © 2015-2021 the original authors.
        #
        # Licensed under the Apache License, Version 2.0 (the "License");
        # you may not use this file except in compliance with the License.
        # You may obtain a copy of the License at
        #
        #      https://www.apache.org/licenses/LICENSE-2.0
        #
        # Unless required by applicable law or agreed to in writing, software
        # distributed under the License is distributed on an "AS IS" BASIS,
        # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        # See the License for the specific language governing permissions and
        # limitations under the License.
        #

        ##############################################################################
        #
        #   Gradle start up script for POSIX generated by Gradle.
        #
        ##############################################################################

        # Attempt to set APP_HOME

        # Resolve links: $0 may be a link
        app_path=$0

        # Need this for daisy-chained symlinks.
        while
            APP_HOME=${app_path%"${app_path##*/}"}  # leaves a trailing /; empty if no leading path
            [ -h "$app_path" ]
        do
            ls=$( ls -ld -- "$app_path" )
            link=${ls#*' -> '}
            case $link in             #(
              /*)   app_path=$link ;; #(
              *)    app_path=$APP_HOME$link ;;
            esac
        done

        # This is normally unused
        # shellcheck disable=SC2034
        APP_BASE_NAME=${0##*/}
        # Discard cd standard output in case $CDPATH is set (https://github.com/gradle/gradle/issues/25036)
        APP_HOME=$( cd "${APP_HOME:-./}" > /dev/null && pwd -P ) || exit

        # Use the maximum available, or set MAX_FD != -1 to use that value.
        MAX_FD=maximum

        warn () {
            echo "$*"
        } >&2

        die () {
            echo
            echo "$*"
            echo
            exit 1
        } >&2

        # OS specific support (must be 'true' or 'false').
        cygwin=false
        msys=false
        darwin=false
        nonstop=false
        case "$( uname )" in                #(
          CYGWIN* )         cygwin=true  ;; #(
          Darwin* )         darwin=true  ;; #(
          MSYS* | MINGW* )  msys=true   ;; #(
          NonStop* )        nonstop=true ;;
        esac

        CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar


        # Determine the Java command to use to start the JVM.
        if [ -n "$JAVA_HOME" ] ; then
            if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
                # IBM's JDK on AIX uses strange locations for the executables
                JAVACMD=$JAVA_HOME/jre/sh/java
            else
                JAVACMD=$JAVA_HOME/bin/java
            fi
            if [ ! -x "$JAVACMD" ] ; then
                die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME

        Please set the JAVA_HOME variable in your environment to match the
        location of your Java installation."
            fi
        else
            JAVACMD=java
            if ! command -v java >/dev/null 2>&1 ; then
                die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.

        Please set the JAVA_HOME variable in your environment to match the
        location of your Java installation."
            fi
        fi

        # Increase the maximum file descriptors if we can.
        if ! "$cygwin" && ! "$darwin" && ! "$nonstop" ; then
            case $MAX_FD in #(
              max*)
                # In POSIX sh, ulimit -H is undefined. That's why the result is checked to see if it worked.
                # shellcheck disable=SC2039,SC3045
                MAX_FD=$( ulimit -H -n ) ||
                    warn "Could not query maximum file descriptor limit"
              ;;
            esac
            case $MAX_FD in  #(
              '' | soft) :;; #(
              *)
                # In POSIX sh, ulimit -n is undefined. That's why the result is checked to see if it worked.
                # shellcheck disable=SC2039,SC3045
                ulimit -n "$MAX_FD" ||
                    warn "Could not set maximum file descriptor limit to $MAX_FD"
              ;;
            esac
        fi

        # Collect all arguments for the java command, stracks://issues.apache.org/jira/browse/GROOVY-://github.com/gradle/gradle/pull/27083#issuecomment-1894708498
        # Discard cd standard output in case $CDPATH is set (https://github.com/gradle/gradle/issues/25036)
        if ! "$cygwin" && ! "$msys" ; then
            case $0 in #(
              *[!a-zA-Z0-9_/-]*)
                APP_HOME=$( cd "${APP_HOME:-./}" > /dev/null && pwd -P ) || exit
              ;;
            esac
        fi


        # Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
        DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'

        # Collect all arguments for the java command;
        #   * $DEFAULT_JVM_OPTS, $JAVA_OPTS, and $GRADLE_OPTS can contain fragments of
        #     shell script including quotes and variable substitutions, so put them in
        #     temporary variables to preserve quoting.
        #   * Put user-defined arguments last, so that they can override default options.
        set -- \
                "-Dorg.gradle.appname=$APP_BASE_NAME" \
                -classpath "$CLASSPATH" \
                org.gradle.wrapper.GradleWrapperMain \
                "$@"

        # Stop when "xeli" is available, i.e., not a shell built-in.
        if "$cygwin" || "$msys" ; then
            # Workaround for bug in cmd with ^ as line continuation:
            # Cmd.exe reads a line, expands variables, reads and appends the next line if ^ is at the end.
            # So, for a multiline command that starts with ^ (which is the case when DEFAULT_JVM_OPTS starts
            # with -), cmd.exe would read it incorrectly. The work-around is to have it start without ^.
            GRADLE_OPTS="$GRADLE_OPTS"
        fi

        exec "$JAVACMD" "$@"
        """##
    }

    private static func generateGradlewBat() -> String {
        return """
        @rem
        @rem Copyright 2015 the original author or authors.
        @rem
        @rem Licensed under the Apache License, Version 2.0 (the "License");
        @rem you may not use this file except in compliance with the License.
        @rem You may obtain a copy of the License at
        @rem
        @rem      https://www.apache.org/licenses/LICENSE-2.0
        @rem
        @rem Unless required by applicable law or agreed to in writing, software
        @rem distributed under the License is distributed on an "AS IS" BASIS,
        @rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        @rem See the License for the specific language governing permissions and
        @rem limitations under the License.
        @rem

        @if "%DEBUG%"=="" @echo off
        @rem ##########################################################################
        @rem
        @rem  Gradle startup script for Windows
        @rem
        @rem ##########################################################################

        @rem Set local scope for the variables with windows NT shell
        if "%OS%"=="Windows_NT" setlocal

        set DIRNAME=%~dp0
        if "%DIRNAME%"=="" set DIRNAME=.
        @rem This is normally unused
        set APP_BASE_NAME=%~n0
        set APP_HOME=%DIRNAME%

        @rem Resolve any "." and ".." in APP_HOME to make it shorter.
        for %%i in ("%APP_HOME%") do set APP_HOME=%%~fi

        @rem Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
        set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"

        @rem Find java.exe
        if defined JAVA_HOME goto findJavaFromJavaHome

        set JAVA_EXE=java.exe
        %JAVA_EXE% -version >NUL 2>&1
        if %ERRORLEVEL% equ 0 goto execute

        echo. 1>&2
        echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH. 1>&2
        echo. 1>&2
        echo Please set the JAVA_HOME variable in your environment to match the 1>&2
        echo location of your Java installation. 1>&2

        goto fail

        :findJavaFromJavaHome
        set JAVA_HOME=%JAVA_HOME:"=%
        set JAVA_EXE=%JAVA_HOME%/bin/java.exe

        if exist "%JAVA_EXE%" goto execute

        echo. 1>&2
        echo ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME% 1>&2
        echo. 1>&2
        echo Please set the JAVA_HOME variable in your environment to match the 1>&2
        echo location of your Java installation. 1>&2

        goto fail

        :execute
        @rem Setup the command line

        set CLASSPATH=%APP_HOME%\\gradle\\wrapper\\gradle-wrapper.jar


        @rem Execute Gradle
        "%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*

        :end
        @rem End local scope for the variables with windows NT shell
        if %OS%=="Windows_NT" endlocal

        :omega
        """
    }

    private static func generateGradleWrapperProperties() -> String {
        return """
        distributionBase=GRADLE_USER_HOME
        distributionPath=wrapper/dists
        distributionUrl=https\\://services.gradle.org/distributions/gradle-8.9-bin.zip
        networkTimeout=10000
        validateDistributionUrl=true
        zipStoreBase=GRADLE_USER_HOME
        zipStorePath=wrapper/dists
        """
    }

    private static func generateLibsVersionsToml() -> String {
        return """
        [versions]
        agp = "8.7.3"
        kotlin = "2.1.0"
        compose-bom = "2024.12.01"
        navigation = "2.8.5"
        serialization = "1.7.3"
        kaml = "0.67.0"
        okhttp = "4.12.0"
        coil = "2.7.0"
        coroutines = "1.9.0"

        [libraries]
        # Compose
        compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
        compose-ui = { group = "androidx.compose.ui", name = "ui" }
        compose-ui-graphics = { group = "androidx.compose.ui", name = "ui-graphics" }
        compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
        compose-material3 = { group = "androidx.compose.material3", name = "material3" }
        compose-material-icons = { group = "androidx.compose.material", name = "material-icons-extended" }
        compose-animation = { group = "androidx.compose.animation", name = "animation" }
        compose-foundation = { group = "androidx.compose.foundation", name = "foundation" }

        # Navigation
        navigation-compose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigation" }

        # Activity
        activity-compose = { group = "androidx.activity", name = "activity-compose", version = "1.9.3" }

        # Lifecycle
        lifecycle-runtime = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version = "2.8.7" }
        lifecycle-viewmodel = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-compose", version = "2.8.7" }

        # Serialization
        serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "serialization" }
        kaml = { group = "com.charleskorn.kaml", name = "kaml", version.ref = "kaml" }

        # Networking
        okhttp = { group = "com.squareup.okhttp3", name = "okhttp", version.ref = "okhttp" }

        # Image loading
        coil-compose = { group = "io.coil-kt", name = "coil-compose", version.ref = "coil" }

        # Coroutines
        coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }

        # Core
        core-ktx = { group = "androidx.core", name = "core-ktx", version = "1.15.0" }

        [plugins]
        android-application = { id = "com.android.application", version.ref = "agp" }
        android-library = { id = "com.android.library", version.ref = "agp" }
        kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
        kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
        kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
        """
    }
}
