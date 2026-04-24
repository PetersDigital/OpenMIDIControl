// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

package com.petersdigital.openmidicontrol

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
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
    
    private val managerScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    // Persistent state for USB Host connection (DAW/PC port open status)
    private val _usbHostConnected = MutableStateFlow(false)
    val usbHostConnected = _usbHostConnected.asStateFlow()

    // Shared flow for incoming MIDI events to be consumed by the UI (when active)
    private val _incomingEvents = MutableSharedFlow<Triple<ByteArray, Int, Long>>(extraBufferCapacity = 1024)
    val incomingEvents = _incomingEvents.asSharedFlow()

    /**
     * Handles MIDI data coming from the PeripheralMidiService (USB client/DAW).
     */
    fun handlePeripheralMidi(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
        // If we're receiving data, the host is definitely connected.
        // This acts as a secondary heart-beat for connection status.
        if (!_usbHostConnected.value) {
            _usbHostConnected.value = true
        }

        // Create a copy of the buffer to avoid data corruption if the service reuses it
        val copy = msg.copyOfRange(offset, offset + count)

        // Dispatch to observers (like MainActivity/Flutter)
        _incomingEvents.tryEmit(Triple(copy, copy.size, timestamp))
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
        managerScope.cancel()
    }
}
