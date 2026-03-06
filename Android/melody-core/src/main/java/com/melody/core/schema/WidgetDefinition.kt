import com.melody.core.schema.ComponentDefinition
import kotlinx.serialization.Serializable
import com.melody.core.schema.Value
import com.melody.core.schema.ValueStringSerializer

@Serializable
enum class WidgetFamily {
    Small, Medium, Large
}

@Serializable
data class WidgetDataFetchDefinition (
    val url: String,
    val method: String? = null,
    val headers: Map<String, String>? = null,
    val body: String? = null,
    val responseType: String? = null
)

@Serializable
data class WidgetDataDefinition (
    val store: List<String> = emptyList(),
    val fetch: WidgetDataFetchDefinition? = null,
    val prepare: String? = null,
)

@Serializable
data class WidgetRefreshMode (
    val interval: Long? = null,
    val requiresNetwork: Boolean? = null
)

@Serializable
data class WidgetLayout (
    @Serializable(with = ValueStringSerializer::class)
    val background: Value<String>? = null,
    val body: List<ComponentDefinition>
)

@Serializable
data class WidgetParameterDefinition(
    val id: String,
    val title: String,
    val type: String = "entity",
    val dependsOn: List<String>? = null,
    val query: String
)

@Serializable
data class WidgetConfigureDefinition(
    val title: String? = null,
    val parameters: List<WidgetParameterDefinition> = emptyList(),
    val resolve: String? = null
)

@Serializable
data class WidgetDefinition(
    val id: String,
    val name: String? = null,
    val description: String? = null,
    val families: List<WidgetFamily> = emptyList(),
    val link: String? = null,
    val data: WidgetDataDefinition? = null,
    val refresh: WidgetRefreshMode? = null,
    val configure: WidgetConfigureDefinition? = null,
    val layouts: Map<WidgetFamily, WidgetLayout>? = null
)
