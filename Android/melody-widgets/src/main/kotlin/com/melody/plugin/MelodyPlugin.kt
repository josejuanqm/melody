package com.melody.plugin

import com.android.build.api.artifact.SingleArtifact
import com.android.build.api.variant.AndroidComponentsExtension
import com.android.build.gradle.BaseExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.tasks.TaskProvider
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

class MelodyPlugin : Plugin<Project> {
    override fun apply(project: Project) {
        val extension = project.extensions.create("melody", MelodyExtension::class.java).apply {
            widgetDir.convention(project.layout.projectDirectory.dir("../widgets"))
            packageName.convention(project.group.toString())
        }

        val generateTask = project.tasks.register(
            "generateMelodyGlanceWidgets",
            GenerateGlanceWidgetsTask::class.java
        ) {
            inputDir.set(extension.widgetDir)
            packageName.set(extension.packageName)
            outputDir.set(project.layout.buildDirectory.dir("generated/source/melody/kotlin"))
            receiversFile.set(project.layout.buildDirectory.file("generated/source/melody/receivers_fragment.xml"))
        }

        project.pluginManager.withPlugin("com.android.application") {
            wireSourceSets(project, generateTask)
            wireManifestMerge(project, generateTask)
        }
    }

    private fun wireSourceSets(
        project: Project,
        generateTask: TaskProvider<GenerateGlanceWidgetsTask>
    ) {
        val android = project.extensions.getByType(BaseExtension::class.java)
        val mainSourceSet = android.sourceSets.getByName("main")

        // Wire generated Kotlin sources
        mainSourceSet.kotlin
            .srcDir(generateTask.flatMap { it.outputDir })

        // Wire generated res/xml (widget info XML files)
        mainSourceSet.res
            .srcDir(generateTask.flatMap { it.outputDir.dir("../res") })

        project.tasks.withType(KotlinCompile::class.java).configureEach {
            dependsOn(generateTask)
        }
    }

    /**
     * Uses AGP's Variant API to transform the merged manifest,
     * injecting the generated widget <receiver> declarations.
     */
    private fun wireManifestMerge(
        project: Project,
        generateTask: TaskProvider<GenerateGlanceWidgetsTask>
    ) {
        val androidComponents = project.extensions
            .getByType(AndroidComponentsExtension::class.java)

        androidComponents.onVariants { variant ->
            val mergeTask = project.tasks.register(
                "mergeWidgetManifest${variant.name.replaceFirstChar { it.uppercase() }}",
                MergeWidgetManifestTask::class.java
            ) {
                dependsOn(generateTask)
                receiversFragment.set(generateTask.flatMap { it.receiversFile })
            }

            variant.artifacts.use(mergeTask)
                .wiredWithFiles(
                    MergeWidgetManifestTask::mergedManifest,
                    MergeWidgetManifestTask::updatedManifest
                )
                .toTransform(SingleArtifact.MERGED_MANIFEST)
        }
    }
}
