package com.melody.plugin

import org.gradle.api.file.DirectoryProperty
import org.gradle.api.provider.Property

abstract class MelodyExtension {
    /** Directory containing widget YAML definitions */
    abstract val widgetDir: DirectoryProperty

    /** Package name for generated files */
    abstract val packageName: Property<String>
}