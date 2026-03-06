package com.melody.plugin

import org.gradle.api.DefaultTask
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.TaskAction

/**
 * Transforms the merged AndroidManifest.xml to inject generated widget
 * receiver declarations. Wired via AGP's Variant API `toTransform`.
 */
abstract class MergeWidgetManifestTask : DefaultTask() {

    /** The merged manifest produced by AGP — wired automatically by the Variant API */
    @get:InputFile
    abstract val mergedManifest: RegularFileProperty

    /** Fragment file containing <receiver> XML entries from the code generator */
    @get:InputFile
    abstract val receiversFragment: RegularFileProperty

    /** The transformed manifest — wired automatically by the Variant API */
    @get:OutputFile
    abstract val updatedManifest: RegularFileProperty

    @TaskAction
    fun merge() {
        val manifest = mergedManifest.asFile.get().readText()
        val fragment = receiversFragment.asFile.get().readText().trim()

        val result = if (fragment.isNotEmpty() && manifest.contains("</application>")) {
            manifest.replace("</application>", "$fragment\n    </application>")
        } else {
            manifest
        }

        updatedManifest.asFile.get().writeText(result)
    }
}
