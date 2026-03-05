package com.melody.plugin

import com.charleskorn.kaml.Yaml
import com.charleskorn.kaml.YamlConfiguration
import com.charleskorn.kaml.YamlNode
import com.charleskorn.kaml.YamlScalar
import com.charleskorn.kaml.yamlMap
import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.*
import java.io.File

abstract class GenerateGlanceWidgetsTask : DefaultTask() {

    @get:InputDirectory
    abstract val inputDir: DirectoryProperty

    @get:Input
    abstract val packageName: Property<String>

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    /** XML fragment containing <receiver> and <activity> entries for manifest merging */
    @get:OutputFile
    abstract val receiversFile: RegularFileProperty

    @TaskAction
    fun generate() {
        val outDir = outputDir.get().asFile
        outDir.deleteRecursively()
        outDir.mkdirs()

        val manifestEntries = mutableListOf<String>()

        inputDir.get().asFile.listFiles()
            ?.filter { it.extension in listOf("yaml", "yml") }
            ?.forEach { file ->
                val widgetName = file.nameWithoutExtension
                    .replace(".widget", "")
                    .replaceFirstChar { it.uppercase() }
                val pkg = packageName.get()
                val widget = Yaml(configuration = YamlConfiguration(decodeEnumCaseInsensitive = true)).parseToYamlNode(file.readText())
                var name = widget.yamlMap.get<YamlScalar>("name")?.content ?: widgetName
                name = name
                    .replace(".widget", "")
                    .replaceFirstChar { it.uppercase() }

                val layouts = widget.yamlMap.get<YamlNode>("layouts")
                val families = layouts?.yamlMap?.entries?.keys
                    ?.mapNotNull { it as? YamlScalar }
                    ?.map { it.content }
                    ?: emptyList()

                val configureNode = widget.yamlMap.get<YamlNode>("configure")
                val hasConfigure = configureNode != null

                val refreshNode = widget.yamlMap.get<YamlNode>("refresh")
                val refreshIntervalMinutes = refreshNode?.yamlMap?.get<YamlScalar>("interval")?.content?.toLongOrNull()

                val link = widget.yamlMap.get<YamlScalar>("link")?.content

                val yamlContent = file.readText()

                File(outDir, "${name}Widget.kt").writeText(
                    generateWidget(pkg, name, families, yamlContent, hasConfigure, link)
                )

                File(outDir, "${name}WidgetReceiver.kt").writeText(
                    generateReceiver(pkg, name, hasConfigure)
                )

                if (hasConfigure) {
                    File(outDir, "${name}WidgetConfigActivity.kt").writeText(
                        generateParameterConfigActivity(pkg, name, yamlContent)
                    )
                }

                val xmlDir = File(outDir, "../res/xml").also { it.mkdirs() }
                File(xmlDir, "${name.lowercase()}_widget_info.xml").writeText(
                    generateWidgetInfoXml(pkg, name, families, hasConfigure, refreshIntervalMinutes)
                )

                val xmlName = "${name.lowercase()}_widget_info"
                val fqcn = "$pkg.generated.${name}WidgetReceiver"
                manifestEntries.add(buildReceiverXml(fqcn, xmlName))

                if (hasConfigure) {
                    val activityFqcn = "$pkg.generated.${name}WidgetConfigActivity"
                    manifestEntries.add(buildActivityXml(activityFqcn))
                }
            }

        receiversFile.get().asFile.apply {
            parentFile.mkdirs()
            writeText(manifestEntries.joinToString("\n"))
        }
    }

    private fun buildReceiverXml(className: String, xmlName: String): String {
        return """        <receiver
            android:name="$className"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/$xmlName" />
        </receiver>"""
    }

    private fun buildActivityXml(className: String): String {
        return """        <activity
            android:name="$className"
            android:exported="true"
            android:theme="@android:style/Theme.DeviceDefault.NoActionBar">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_CONFIGURE" />
            </intent-filter>
        </activity>"""
    }

    private fun generateWidget(
        pkg: String,
        name: String,
        families: List<String>,
        yamlContent: String,
        hasConfigure: Boolean,
        link: String? = null
    ): String {
        val sizeModeEntries = families.joinToString(", ") { family ->
            family.replaceFirstChar { it.uppercase() }.uppercase()
        }

        val escapedYaml = yamlContent.replace("$", "\${'\$'}")

        return """
            package $pkg.generated

            import WidgetFamily
            import androidx.compose.ui.unit.dp
            import androidx.compose.ui.unit.DpSize
            import androidx.glance.GlanceId
            import androidx.glance.GlanceModifier
            import androidx.glance.GlanceTheme
            import androidx.glance.LocalSize
            import androidx.glance.appwidget.GlanceAppWidget
            import androidx.glance.appwidget.SizeMode
            import androidx.glance.appwidget.appWidgetBackground
            import androidx.glance.appwidget.cornerRadius
            import androidx.glance.appwidget.provideContent
            import androidx.glance.background
            import androidx.glance.action.clickable
            import androidx.glance.appwidget.action.actionStartActivity
            import androidx.glance.layout.Alignment
            import androidx.glance.layout.Box
            import androidx.glance.layout.fillMaxSize
            import androidx.glance.text.Text
            import androidx.glance.text.TextAlign
            import androidx.glance.text.TextStyle
            import androidx.glance.unit.ColorProvider
            import com.melody.runtime.renderer.GlanceComponentRenderer
            import com.melody.runtime.renderer.loadThemeColors
            import com.melody.runtime.renderer.sizeToFamily
            import com.melody.runtime.components.hexToColor
            import com.melody.runtime.components.resolveColorHex
            import com.melody.runtime.widget.WidgetConfigStore
            import com.melody.runtime.widget.WidgetDataProvider
            import com.melody.runtime.widget.WidgetExpressionResolver
            import com.melody.runtime.widget.WidgetYamlLoader

            class ${name}Widget : GlanceAppWidget() {
                companion object {
                    private val SMALL = DpSize(110.dp, 110.dp)
                    private val MEDIUM = DpSize(250.dp, 110.dp)
                    private val LARGE = DpSize(250.dp, 250.dp)

                    private val WIDGET_YAML = ${"\"\"\""}
$escapedYaml
${"\"\"\""}
                }

                override val sizeMode = SizeMode.Responsive(
                    setOf($sizeModeEntries)
                )

                override suspend fun provideGlance(
                    context: android.content.Context,
                    id: GlanceId
                ) {
                    val widgetDef = WidgetYamlLoader.parse(WIDGET_YAML)
${if (hasConfigure) """
                    val appWidgetId = androidx.glance.appwidget.GlanceAppWidgetManager(context)
                        .getAppWidgetId(id)
                    val configData = WidgetConfigStore.getData(context, appWidgetId)
                    android.util.Log.d("${name}Widget", "provideGlance: appWidgetId=${'$'}appWidgetId, configData=${'$'}configData")
                    val hasSelection = configData != null && configData.isNotEmpty()
                    val data = if (hasSelection) {
                        WidgetDataProvider.resolve(context, widgetDef, appWidgetId)
                    } else {
                        emptyMap()
                    }
                    android.util.Log.d("${name}Widget", "provideGlance: hasSelection=${'$'}hasSelection, dataKeys=${'$'}{data.keys}")""" else """
                    val hasSelection = true
                    val data = WidgetDataProvider.resolve(context, widgetDef)"""}


                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)

                    provideContent {
                        GlanceTheme {
                            val tapModifier = launchIntent?.let {
                                GlanceModifier.clickable(actionStartActivity(it))
                            } ?: GlanceModifier

                            if (!hasSelection) {
                                Box(
                                    modifier = tapModifier
                                        .then(GlanceModifier.fillMaxSize())
                                        .appWidgetBackground()
                                        .background(GlanceTheme.colors.widgetBackground)
                                        .cornerRadius(16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = "Tap and hold to select a ${name.lowercase()}",
                                        style = TextStyle(color = GlanceTheme.colors.onSurface, textAlign = TextAlign.Center)
                                    )
                                }
                            } else {
                                val size = LocalSize.current
                                val family = sizeToFamily(size)
                                val layout = widgetDef.layouts?.get(family)
                                    ?: widgetDef.layouts?.values?.firstOrNull()
                                    ?: return@GlanceTheme

                                val resolved = WidgetExpressionResolver.resolve(layout.body, data)
                                val themeColors = loadThemeColors(context)
                                val bgResolved = WidgetExpressionResolver.resolveValue(layout.background, data)
                                val bgColor = bgResolved?.let {
                                    try { hexToColor(resolveColorHex(it, themeColors)) } catch (_: Exception) { null }
                                }
                                Box(
                                    modifier = tapModifier
                                        .then(GlanceModifier.fillMaxSize())
                                        .appWidgetBackground()
                                        .background(bgColor?.let { ColorProvider(it) } ?: GlanceTheme.colors.widgetBackground)
                                        .cornerRadius(16.dp)
                                ) {
                                    GlanceComponentRenderer(
                                        components = resolved,
                                        themeColors = themeColors
                                    )
                                }
                            }
                        }
                    }
                }
            }
        """.trimIndent()
    }

    private fun generateReceiver(pkg: String, name: String, hasConfigure: Boolean): String {
        if (!hasConfigure) {
            return """
                package $pkg.generated

                import androidx.glance.appwidget.GlanceAppWidget
                import androidx.glance.appwidget.GlanceAppWidgetReceiver

                class ${name}WidgetReceiver : GlanceAppWidgetReceiver() {
                    override val glanceAppWidget: GlanceAppWidget = ${name}Widget()
                }
            """.trimIndent()
        }

        return """
            package $pkg.generated

            import android.content.Context
            import android.content.Intent
            import androidx.glance.appwidget.GlanceAppWidget
            import androidx.glance.appwidget.GlanceAppWidgetReceiver
            import com.melody.runtime.widget.WidgetConfigStore

            class ${name}WidgetReceiver : GlanceAppWidgetReceiver() {
                override val glanceAppWidget: GlanceAppWidget = ${name}Widget()

                override fun onDeleted(context: Context, appWidgetIds: IntArray) {
                    super.onDeleted(context, appWidgetIds)
                    appWidgetIds.forEach { WidgetConfigStore.deleteConfig(context, it) }
                }
            }
        """.trimIndent()
    }

    private fun generateParameterConfigActivity(
        pkg: String,
        name: String,
        yamlContent: String
    ): String {
        val escapedYaml = yamlContent.replace("$", "\${'\$'}")

        return """
            package $pkg.generated

            import android.appwidget.AppWidgetManager
            import android.content.Intent
            import android.os.Bundle
            import androidx.activity.ComponentActivity
            import androidx.activity.compose.setContent
            import androidx.glance.appwidget.GlanceAppWidgetManager
            import androidx.lifecycle.lifecycleScope
            import com.melody.core.parser.AppParser
            import com.melody.runtime.widget.ParameterConfigView
            import com.melody.runtime.widget.WidgetConfigStore
            import com.melody.runtime.widget.WidgetYamlLoader
            import kotlinx.coroutines.launch

            class ${name}WidgetConfigActivity : ComponentActivity() {

                override fun onCreate(savedInstanceState: Bundle?) {
                    super.onCreate(savedInstanceState)

                    setResult(RESULT_CANCELED)

                    val appWidgetId = intent?.extras?.getInt(
                        AppWidgetManager.EXTRA_APPWIDGET_ID,
                        AppWidgetManager.INVALID_APPWIDGET_ID
                    ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

                    if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                        finish()
                        return
                    }

                    val widgetDef = WidgetYamlLoader.parse(WIDGET_YAML)
                    val configure = widgetDef.configure
                    if (configure == null) {
                        finish()
                        return
                    }

                    val appLuaPrelude = try {
                        AppParser().parseFromAssets(this)?.app?.lua
                    } catch (_: Exception) { null }

                    setContent {
                        ParameterConfigView(
                            title = configure.title ?: "Configure",
                            parameters = configure.parameters,
                            resolveLua = configure.resolve,
                            appLuaPrelude = appLuaPrelude,
                            onDone = { data ->
                                WidgetConfigStore.saveData(this, appWidgetId, data)
                                val resultIntent = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                                setResult(RESULT_OK, resultIntent)
                                lifecycleScope.launch {
                                    val manager = GlanceAppWidgetManager(this@${name}WidgetConfigActivity)
                                    val glanceId = manager.getGlanceIds(${name}Widget::class.java).firstOrNull()
                                    if (glanceId != null) {
                                        ${name}Widget().update(this@${name}WidgetConfigActivity, glanceId)
                                    }
                                }
                                finish()
                            },
                            onCancel = { finish() }
                        )
                    }
                }

                companion object {
                    private val WIDGET_YAML = ${"\"\"\""}
$escapedYaml
${"\"\"\""}
                }
            }
        """.trimIndent()
    }

    private fun generateWidgetInfoXml(
        pkg: String,
        name: String,
        families: List<String>,
        hasConfigure: Boolean,
        refreshIntervalMinutes: Long?
    ): String {
        val hasSmall = "small" in families.map { it.lowercase() }
        val hasMedium = "medium" in families.map { it.lowercase() }
        val hasLarge = "large" in families.map { it.lowercase() }

        val minW = if (hasSmall) 110 else 250
        val minH = 110
        val maxW = if (hasLarge || hasMedium) 530 else 110
        val maxH = if (hasLarge) 400 else if (hasMedium) 250 else 110

        val resize = buildList {
            if (hasMedium || hasLarge) add("horizontal")
            if (hasLarge || hasMedium) add("vertical")
        }.joinToString("|").ifEmpty { "none" }

        val configureAttr = if (hasConfigure) {
            """
                android:configure="$pkg.generated.${name}WidgetConfigActivity"
                android:widgetFeatures="reconfigurable""""
        } else {
            ""
        }

        val updateMillis = if (refreshIntervalMinutes != null) {
            val ms = refreshIntervalMinutes * 60_000
            val clamped = ms.coerceAtLeast(1_800_000)
            """
                android:updatePeriodMillis="$clamped""""
        } else {
            ""
        }

        return """
            <?xml version="1.0" encoding="utf-8"?>
            <appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
                android:minWidth="${minW}dp"
                android:minHeight="${minH}dp"
                android:maxResizeWidth="${maxW}dp"
                android:maxResizeHeight="${maxH}dp"
                android:resizeMode="$resize"
                android:widgetCategory="home_screen"$configureAttr$updateMillis
                android:initialLayout="@layout/glance_default_loading_layout" />
        """.trimIndent()
    }
}
