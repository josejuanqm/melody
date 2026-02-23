package com.melody.runtime.devclient

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext

/**
 * Shake detection based on Square's Seismic library algorithm.
 * Uses a sample queue over a 0.5s window — if ≥75% of samples are
 * accelerating above the threshold, a shake is detected.
 */
@Composable
fun ShakeDetector(onShake: () -> Unit) {
    val context = LocalContext.current

    DisposableEffect(Unit) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        val accelerationThreshold = 11 // SENSITIVITY_LIGHT from Seismic
        val thresholdSquared = accelerationThreshold * accelerationThreshold
        val windowNanos = 500_000_000L // 0.5 seconds
        val minSamples = 4
        val minAcceleratingRatio = 0.75

        // Linked-list sample queue
        class Sample(
            var timestamp: Long = 0L,
            var accelerating: Boolean = false,
            var next: Sample? = null
        )

        var oldest: Sample? = null
        var newest: Sample? = null
        var sampleCount = 0
        var acceleratingCount = 0

        fun clear() {
            oldest = null
            newest = null
            sampleCount = 0
            acceleratingCount = 0
        }

        fun purge(cutoff: Long) {
            while (sampleCount >= minSamples) {
                val o = oldest ?: break
                if (o.timestamp >= cutoff) break
                oldest = o.next
                sampleCount--
                if (o.accelerating) acceleratingCount--
            }
        }

        fun addSample(timestamp: Long, accelerating: Boolean): Boolean {
            purge(timestamp - windowNanos)

            val sample = Sample(timestamp, accelerating)
            if (oldest == null) {
                oldest = sample
            } else {
                newest?.next = sample
            }
            newest = sample
            sampleCount++
            if (accelerating) acceleratingCount++

            return sampleCount >= minSamples &&
                    acceleratingCount.toDouble() / sampleCount >= minAcceleratingRatio
        }

        fun isAccelerating(event: SensorEvent): Boolean {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]
            val magnitudeSquared = (x * x + y * y + z * z).toDouble()
            // Compare squared values to avoid sqrt
            return magnitudeSquared > thresholdSquared * SensorManager.GRAVITY_EARTH * SensorManager.GRAVITY_EARTH
        }

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val accelerating = isAccelerating(event)
                val timestamp = event.timestamp
                if (addSample(timestamp, accelerating)) {
                    clear()
                    onShake()
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        accelerometer?.let {
            sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_UI)
        }

        onDispose {
            sensorManager.unregisterListener(listener)
            clear()
        }
    }
}
