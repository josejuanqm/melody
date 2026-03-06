package com.melody.runtime.widget

import WidgetDefinition
import com.charleskorn.kaml.Yaml
import com.charleskorn.kaml.YamlConfiguration

/**
 * Parses widget YAML definitions at runtime.
 * Used by generated widget classes to deserialize their embedded YAML.
 */
object WidgetYamlLoader {

    fun parse(yaml: String): WidgetDefinition {
        return Yaml(configuration = YamlConfiguration(decodeEnumCaseInsensitive = true)).decodeFromString(WidgetDefinition.serializer(), yaml.trimIndent())
    }
}
