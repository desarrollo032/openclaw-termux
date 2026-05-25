package com.nxg.openclawproot

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.location.LocationProvider

class LocationHelper(private val context: Context) {

    private val locationManager: LocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    data class LocationResult(
        val latitude: Double,
        val longitude: Double,
        val accuracy: Float,
        val altitude: Double,
        val timestamp: Long
    )

    /** Check if any location provider is enabled. */
    fun isLocationServiceEnabled(): Boolean {
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    /** Get last known location from any provider. */
    fun getLastKnownLocation(): LocationResult? {
        // Try GPS first, then Network, then Passive
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
        for (provider in providers) {
            try {
                val location = locationManager.getLastKnownLocation(provider)
                if (location != null) {
                    return toResult(location)
                }
            } catch (_: SecurityException) {
                // Permission not granted for this provider
            } catch (_: IllegalArgumentException) {
                // Provider doesn't exist
            }
        }
        return null
    }

    /**
     * Get current location by requesting a single GPS fix.
     * This is a blocking call — run on a background thread.
     */
    @Throws(SecurityException::class, Exception::class)
    fun getCurrentLocation(timeoutMs: Long = 10_000): LocationResult? {
        // Try GPS first
        if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            try {
                val loc = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                if (loc != null && System.currentTimeMillis() - loc.time < 60_000) {
                    // Use last known if it's recent (< 1 min)
                    return toResult(loc)
                }
            } catch (_: Exception) {}
        }

        // Fall back to Network provider
        if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            try {
                val loc = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                if (loc != null) {
                    return toResult(loc)
                }
            } catch (_: Exception) {}
        }

        return getLastKnownLocation()
    }

    private fun toResult(location: Location): LocationResult {
        return LocationResult(
            latitude = location.latitude,
            longitude = location.longitude,
            accuracy = location.accuracy,
            altitude = location.altitude,
            timestamp = location.time
        )
    }
}
