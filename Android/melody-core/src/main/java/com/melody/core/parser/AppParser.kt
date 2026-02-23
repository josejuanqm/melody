package com.melody.core.parser

import android.content.Context
import com.charleskorn.kaml.Yaml
import com.charleskorn.kaml.YamlConfiguration
import com.melody.core.schema.AppDefinition
import com.melody.core.schema.CustomComponentDefinition
import com.melody.core.schema.ScreenDefinition
import java.io.File

class ParserError(message: String) : Exception(message)

/**
 * Parses YAML app definitions into typed schema models.
 * Port of iOS AppParser.swift.
 */
class AppParser {
    private val yaml = Yaml(
        configuration = YamlConfiguration(
            strictMode = false
        )
    )

    /** Parse a YAML string into an AppDefinition */
    fun parse(yamlString: String): AppDefinition {
        return yaml.decodeFromString(AppDefinition.serializer(), yamlString)
    }

    /** Parse a YAML file at the given path */
    fun parseFile(path: String): AppDefinition {
        val content = File(path).readText()
        return parse(content)
    }

    /**
     * Parse a directory containing app.yaml and screen files in subdirectories.
     */
    fun parseDirectory(dirPath: String): AppDefinition {
        val dir = File(dirPath)
        val appFile = File(dir, "app.yaml")

        if (!appFile.exists()) {
            throw ParserError("No app.yaml found in directory: $dirPath")
        }

        val app = parseFile(appFile.absolutePath)

        val componentFiles = findComponentFiles(dir)
        for (filePath in componentFiles) {
            val compYaml = File(filePath).readText()
            val component = yaml.decodeFromString(CustomComponentDefinition.serializer(), compYaml)
            val name = component.name ?: continue
            if (app.components == null) app.components = mutableMapOf()
            app.components!![name] = component
        }

        val screenFiles = findYAMLFiles(dir, "app.yaml")
        for (filePath in screenFiles) {
            val screenYaml = File(filePath).readText()
            val screen = yaml.decodeFromString(ScreenDefinition.serializer(), screenYaml)
            app.screens.add(screen)
        }

        return app
    }

    /**
     * Parse app definition from Android assets directory.
     * Loads app.yaml and all screen YAML files from subdirectories.
     */
    fun parseFromAssets(context: Context, rootPath: String = ""): AppDefinition {
        val assetManager = context.assets

        val appYamlPath = if (rootPath.isEmpty()) "app.yaml" else "$rootPath/app.yaml"
        val appYaml = assetManager.open(appYamlPath).bufferedReader().readText()
        val app = parse(appYaml)

        val componentsDir = if (rootPath.isEmpty()) "components" else "$rootPath/components"
        try {
            val componentAssetFiles = listAssetFiles(context, componentsDir)
            for (filePath in componentAssetFiles) {
                if (filePath.endsWith(".component.yaml")) {
                    try {
                        val compYaml = assetManager.open(filePath).bufferedReader().readText()
                        val component = yaml.decodeFromString(CustomComponentDefinition.serializer(), compYaml)
                        val name = component.name ?: continue
                        if (app.components == null) app.components = mutableMapOf()
                        app.components!![name] = component
                    } catch (e: Exception) {
                        android.util.Log.e("Melody", "Failed to parse component: $filePath", e)
                    }
                }
            }
        } catch (_: Exception) { }

        val screensDir = if (rootPath.isEmpty()) "screens" else "$rootPath/screens"
        try {
            val screenFiles = listAssetFiles(context, screensDir)
            for (filePath in screenFiles) {
                if ((filePath.endsWith(".yaml") || filePath.endsWith(".yml")) &&
                    !filePath.endsWith(".component.yaml")) {
                    try {
                        val screenYaml = assetManager.open(filePath).bufferedReader().readText()
                        val screen = yaml.decodeFromString(ScreenDefinition.serializer(), screenYaml)
                        app.screens.add(screen)
                    } catch (e: Exception) {
                        android.util.Log.e("Melody", "Failed to parse screen: $filePath", e)
                    }
                }
            }
        } catch (_: Exception) { }

        return app
    }

    /**
     * Merge directory back into a single YAML string (for hot reload).
     */
    fun mergeDirectoryToYAML(dirPath: String): String {
        val dir = File(dirPath)
        val appFile = File(dir, "app.yaml")
        var appYaml = appFile.readText()

        val componentFiles = findComponentFiles(dir)
        if (componentFiles.isNotEmpty()) {
            if (!appYaml.contains("\ncomponents:") && !appYaml.contains("\ncomponents :")) {
                appYaml += "\ncomponents:\n"
            }
            for (filePath in componentFiles) {
                val compYaml = File(filePath).readText()
                val lines = compYaml.split("\n")
                var name: String? = null
                val bodyLines = mutableListOf<String>()
                for (line in lines) {
                    val trimmed = line.trim()
                    if (trimmed.startsWith("name:") && name == null) {
                        name = trimmed.removePrefix("name:").trim()
                    } else {
                        bodyLines.add(line)
                    }
                }
                if (name.isNullOrEmpty()) continue
                val indentedBody = bodyLines.joinToString("\n") {
                    if (it.isEmpty()) "" else "    $it"
                }
                appYaml += "  $name:\n$indentedBody\n"
            }
        }

        val screenFiles = findYAMLFiles(dir, "app.yaml")
        if (screenFiles.isNotEmpty()) {
            if (!appYaml.contains("\nscreens:") && !appYaml.contains("\nscreens :")) {
                appYaml += "\nscreens:\n"
            }

            for (filePath in screenFiles) {
                val screenYaml = File(filePath).readText()
                appYaml += "  - " + screenYaml.replace("\n", "\n    ") + "\n"
            }
        }

        return appYaml
    }

    companion object {
        /**
         * Recursively find all YAML files in subdirectories, excluding a root file
         * and component files (*.component.yaml).
         */
        fun findYAMLFiles(dir: File, excludeRootFile: String): List<String> {
            val results = mutableListOf<String>()
            dir.walk()
                .filter { it.isFile }
                .filter { it.name != excludeRootFile }
                .filter { !it.name.startsWith(".") }
                .filter { it.extension == "yaml" || it.extension == "yml" }
                .filter { !it.name.endsWith(".component.yaml") }
                .forEach { results.add(it.absolutePath) }
            return results.sorted()
        }

        /**
         * Recursively find all *.component.yaml files in a directory.
         */
        fun findComponentFiles(dir: File): List<String> {
            val results = mutableListOf<String>()
            dir.walk()
                .filter { it.isFile }
                .filter { !it.name.startsWith(".") }
                .filter { it.name.endsWith(".component.yaml") }
                .forEach { results.add(it.absolutePath) }
            return results.sorted()
        }

        /**
         * Recursively list asset files under a given path.
         */
        private fun listAssetFiles(context: Context, path: String): List<String> {
            val results = mutableListOf<String>()
            val assetManager = context.assets
            val files = assetManager.list(path) ?: return results
            for (file in files) {
                val fullPath = "$path/$file"
                val subFiles = assetManager.list(fullPath)
                if (subFiles != null && subFiles.isNotEmpty()) {
                    results.addAll(listAssetFiles(context, fullPath))
                } else {
                    results.add(fullPath)
                }
            }
            return results.sorted()
        }
    }
}
