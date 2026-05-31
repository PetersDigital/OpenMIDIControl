// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

package com.petersdigital.openmidicontrol

import android.util.Log
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * A persistent, activity-independent manager for MIDI state and transport.
 * This ensures that core MIDI routing and service communication continue
 * during transient activity focus shifts or backgrounding.
 */
object MidiSystemManager {
    private const val TAG = "MidiSystemManager"
    
    // Persistent state for USB Host connection (DAW/PC port open status)
    private val _usbHostConnected = MutableStateFlow(false)
    val usbHostConnected = _usbHostConnected.asStateFlow()

    // Shared flow for incoming MIDI events to be consumed by the UI (when active)
    private val _incomingEvents = MutableSharedFlow<Long>(extraBufferCapacity = 1024)
    val incomingEvents = _incomingEvents.asSharedFlow()

    // Shared flow for port failures (IOExceptions, etc.)
    private val _portFailures = MutableSharedFlow<String>(extraBufferCapacity = 16)
    val portFailures = _portFailures.asSharedFlow()

    /**
     * Handles MIDI data coming from the PeripheralMidiService (USB client/DAW).
     */
    fun handlePeripheralMidi(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
        // If we're receiving data, the host is definitely connected.
        // This acts as a secondary heart-beat for connection status.
        if (!_usbHostConnected.value) {
            _usbHostConnected.value = true
        }

        // Dispatch to observers (like MainActivity/Flutter)
        // Ensure count is at least 4 before processing to avoid IndexOutOfBounds
        if (count >= 4) {
            val byte1 = msg[offset].toInt() and 0xFF
            val byte2 = msg[offset + 1].toInt() and 0xFF
            val byte3 = msg[offset + 2].toInt() and 0xFF
            val byte4 = msg[offset + 3].toInt() and 0xFF
            val ump = (byte1 shl 24) or (byte2 shl 16) or (byte3 shl 8) or byte4
            val packed = ((ump.toLong() and 0xFFFFFFFFL) shl 32) or (timestamp and 0xFFFFFFFFL)
            _incomingEvents.tryEmit(packed)
        } else {
            // Unlikely fallback for non-UMP byte stream logic, but since this specific request targets
            // elimination of Pair allocations by packing UMP + timestamp, we'll try to accommodate single bytes too
            // Actually, the instruction says: "pack event into Long: upper 32 bits = UMP, lower 32 bits = timestamp"
            var ump = 0
            for (i in 0 until Math.min(count, 4)) {
                ump = ump or ((msg[offset + i].toInt() and 0xFF) shl (24 - (i * 8)))
            }
            val packed = ((ump.toLong() and 0xFFFFFFFFL) shl 32) or (timestamp and 0xFFFFFFFFL)
            _incomingEvents.tryEmit(packed)
        }
    }

    /**
     * Notifies the system that a port has failed fatally (e.g. IOException).
     */
    fun onPortFailure(portId: String) {
        Log.e(TAG, "Fatal failure on port: $portId")
        _portFailures.tryEmit(portId)
    }

    /**
     * Notifies the system that a USB host has connected/disconnected.
     */
    fun setUsbHostConnected(connected: Boolean) {
        _usbHostConnected.value = connected
    }

    /**
     * Cleanup resources when the application process is being terminated.
     */
    fun teardown() {
        Log.i(TAG, "Tearing down MidiSystemManager")
    }
}
