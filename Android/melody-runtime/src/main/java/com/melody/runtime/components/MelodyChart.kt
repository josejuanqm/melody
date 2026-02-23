package com.melody.runtime.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.melody.core.schema.ComponentDefinition
import com.melody.core.schema.MarkDefinition
import com.melody.core.schema.resolved
import com.melody.runtime.engine.LuaValue
import com.melody.runtime.renderer.LocalThemeColors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

data class ChartDataPoint(
    val id: Int,
    val values: Map<String, ChartValue>
) {
    fun string(key: String): String = values[key]?.stringValue ?: ""
    fun number(key: String): Double = values[key]?.numberValue ?: 0.0
}

sealed class ChartValue {
    data class NumberValue(val value: Double) : ChartValue()
    data class TextValue(val value: String) : ChartValue()

    val stringValue: String
        get() = when (this) {
            is NumberValue -> if (value == value.toLong().toDouble() && value < 1e15) value.toLong().toString() else value.toString()
            is TextValue -> value
        }

    val numberValue: Double
        get() = when (this) {
            is NumberValue -> value
            is TextValue -> 0.0
        }
}

private val defaultColors = listOf(
    Color(0xFF2196F3),
    Color(0xFFF44336),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF3F51B5),
)

@Composable
fun MelodyChart(
    definition: ComponentDefinition,
    resolvedItems: List<LuaValue>
) {
    val themeColors = LocalThemeColors.current
    val marks = definition.marks ?: return
    val dataPoints = extractDataPoints(resolvedItems, marks)
    val chartColors = definition.colors?.map { parseColor(it, themeColors) ?: Color.Blue } ?: defaultColors

    val hasSector = marks.any { it.type.lowercase() == "sector" }

    if (hasSector) {
        val sectorMark = marks.first { it.type.lowercase() == "sector" }
        SectorChart(dataPoints, sectorMark, chartColors, definition)
    } else {
        CartesianChart(dataPoints, marks, chartColors, definition)
    }
}

@Composable
private fun CartesianChart(
    dataPoints: List<ChartDataPoint>,
    marks: List<MarkDefinition>,
    colors: List<Color>,
    definition: ComponentDefinition
) {
    if (dataPoints.isEmpty()) return

    Canvas(
        modifier = Modifier
            .melodyStyle(definition.style)
            .then(if (definition.style?.height == null) Modifier.height(200.dp) else Modifier)
            .then(if (definition.style?.width == null) Modifier.fillMaxWidth() else Modifier)
    ) {
        val padding = 40f
        val chartWidth = size.width - padding * 2
        val chartHeight = size.height - padding * 2

        for ((markIndex, mark) in marks.withIndex()) {
            val color = colors[markIndex % colors.size]
            val yKey = mark.yKey ?: "y"

            val maxY = dataPoints.maxOfOrNull { it.number(yKey) } ?: 1.0
            val minY = dataPoints.minOfOrNull { it.number(yKey) } ?: 0.0
            val range = if (maxY == minY) 1.0 else maxY - minY

            when (mark.type.lowercase()) {
                "bar" -> drawBarMark(dataPoints, yKey, minY, range, padding, chartWidth, chartHeight, color)
                "line" -> drawLineMark(dataPoints, yKey, minY, range, padding, chartWidth, chartHeight, color, mark)
                "point" -> drawPointMark(dataPoints, yKey, minY, range, padding, chartWidth, chartHeight, color, mark)
                "area" -> drawAreaMark(dataPoints, yKey, minY, range, padding, chartWidth, chartHeight, color)
                "rule" -> drawRuleMark(mark, minY, range, padding, chartWidth, chartHeight, color)
            }
        }
    }
}

private fun DrawScope.drawBarMark(
    dataPoints: List<ChartDataPoint>,
    yKey: String,
    minY: Double,
    range: Double,
    padding: Float,
    chartWidth: Float,
    chartHeight: Float,
    color: Color
) {
    val barWidth = chartWidth / dataPoints.size * 0.8f
    val gap = chartWidth / dataPoints.size * 0.1f

    for ((i, point) in dataPoints.withIndex()) {
        val y = point.number(yKey)
        val barHeight = ((y - minY) / range * chartHeight).toFloat()
        val x = padding + i * (barWidth + gap * 2) + gap

        drawRect(
            color = color,
            topLeft = Offset(x, padding + chartHeight - barHeight),
            size = Size(barWidth, barHeight)
        )
    }
}

private fun DrawScope.drawLineMark(
    dataPoints: List<ChartDataPoint>,
    yKey: String,
    minY: Double,
    range: Double,
    padding: Float,
    chartWidth: Float,
    chartHeight: Float,
    color: Color,
    mark: MarkDefinition
) {
    if (dataPoints.size < 2) return
    val lineWidth = (mark.lineWidth ?: 2.0).toFloat()
    val path = Path()

    for ((i, point) in dataPoints.withIndex()) {
        val y = point.number(yKey)
        val px = padding + (i.toFloat() / (dataPoints.size - 1)) * chartWidth
        val py = padding + chartHeight - ((y - minY) / range * chartHeight).toFloat()

        if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
    }

    drawPath(path, color, style = Stroke(width = lineWidth))
}

private fun DrawScope.drawPointMark(
    dataPoints: List<ChartDataPoint>,
    yKey: String,
    minY: Double,
    range: Double,
    padding: Float,
    chartWidth: Float,
    chartHeight: Float,
    color: Color,
    mark: MarkDefinition
) {
    val radius = ((mark.symbolSize ?: 64.0) / 16).toFloat()

    for ((i, point) in dataPoints.withIndex()) {
        val y = point.number(yKey)
        val px = padding + (i.toFloat() / (dataPoints.size - 1).coerceAtLeast(1)) * chartWidth
        val py = padding + chartHeight - ((y - minY) / range * chartHeight).toFloat()

        drawCircle(color, radius, Offset(px, py))
    }
}

private fun DrawScope.drawAreaMark(
    dataPoints: List<ChartDataPoint>,
    yKey: String,
    minY: Double,
    range: Double,
    padding: Float,
    chartWidth: Float,
    chartHeight: Float,
    color: Color
) {
    if (dataPoints.size < 2) return
    val path = Path()
    val baseline = padding + chartHeight

    path.moveTo(padding, baseline)
    for ((i, point) in dataPoints.withIndex()) {
        val y = point.number(yKey)
        val px = padding + (i.toFloat() / (dataPoints.size - 1)) * chartWidth
        val py = padding + chartHeight - ((y - minY) / range * chartHeight).toFloat()
        path.lineTo(px, py)
    }
    path.lineTo(padding + chartWidth, baseline)
    path.close()

    drawPath(path, color.copy(alpha = 0.3f))
}

private fun DrawScope.drawRuleMark(
    mark: MarkDefinition,
    minY: Double,
    range: Double,
    padding: Float,
    chartWidth: Float,
    chartHeight: Float,
    color: Color
) {
    val lineWidth = (mark.lineWidth ?: 1.0).toFloat()
    mark.yValue?.let { yVal ->
        val py = padding + chartHeight - ((yVal - minY) / range * chartHeight).toFloat()
        drawLine(color, Offset(padding, py), Offset(padding + chartWidth, py), strokeWidth = lineWidth)
    }
}

@Composable
private fun SectorChart(
    dataPoints: List<ChartDataPoint>,
    mark: MarkDefinition,
    colors: List<Color>,
    definition: ComponentDefinition
) {
    val angleKey = mark.angleKey ?: "value"
    val total = dataPoints.sumOf { it.number(angleKey) }
    if (total == 0.0) return

    val innerRadiusRatio = (mark.innerRadius ?: 0.0).toFloat()

    Canvas(
        modifier = Modifier
            .melodyStyle(definition.style)
            .then(if (definition.style?.height == null) Modifier.height(200.dp) else Modifier)
            .then(if (definition.style?.width == null) Modifier.fillMaxWidth() else Modifier)
    ) {
        val radius = minOf(size.width, size.height) / 2 * 0.9f
        val innerRadius = radius * innerRadiusRatio
        val center = Offset(size.width / 2, size.height / 2)
        var startAngle = -90f

        for ((i, point) in dataPoints.withIndex()) {
            val value = point.number(angleKey)
            val sweepAngle = (value / total * 360).toFloat()
            val color = colors[i % colors.size]

            if (innerRadius > 0) {
                drawArc(
                    color = color,
                    startAngle = startAngle,
                    sweepAngle = sweepAngle,
                    useCenter = true,
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = Size(radius * 2, radius * 2)
                )
                drawCircle(
                    color = Color.White,
                    radius = innerRadius,
                    center = center
                )
            } else {
                drawArc(
                    color = color,
                    startAngle = startAngle,
                    sweepAngle = sweepAngle,
                    useCenter = true,
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = Size(radius * 2, radius * 2)
                )
            }

            startAngle += sweepAngle
        }
    }
}

private fun extractDataPoints(items: List<LuaValue>, marks: List<MarkDefinition>): List<ChartDataPoint> {
    val allKeys = mutableSetOf<String>()
    for (mark in marks) {
        mark.xKey?.let { allKeys.add(it) }
        mark.yKey?.let { allKeys.add(it) }
        mark.groupKey?.let { allKeys.add(it) }
        mark.angleKey?.let { allKeys.add(it) }
        mark.xStartKey?.let { allKeys.add(it) }
        mark.xEndKey?.let { allKeys.add(it) }
        mark.yStartKey?.let { allKeys.add(it) }
        mark.yEndKey?.let { allKeys.add(it) }
    }

    return items.mapIndexedNotNull { index, item ->
        val table = item.tableValue ?: return@mapIndexedNotNull null
        val values = mutableMapOf<String, ChartValue>()
        for (key in allKeys) {
            val luaVal = table[key] ?: continue
            when (luaVal) {
                is LuaValue.NumberVal -> values[key] = ChartValue.NumberValue(luaVal.value)
                is LuaValue.StringVal -> {
                    val n = luaVal.value.toDoubleOrNull()
                    values[key] = if (n != null) ChartValue.NumberValue(n) else ChartValue.TextValue(luaVal.value)
                }
                is LuaValue.BoolVal -> values[key] = ChartValue.TextValue(if (luaVal.value) "true" else "false")
                else -> values[key] = ChartValue.TextValue(luaVal.toString())
            }
        }
        ChartDataPoint(id = index, values = values)
    }
}
