// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver
import android.util.Log
import java.io.IOException
import kotlinx.coroutines.*

class PeripheralMidiService : MidiDeviceService() {
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val deadReceivers = mutableSetOf<MidiReceiver>()
 
    companion object {
        var activeInstance: PeripheralMidiService? = null
    }

    // Cached receiver — allocated once to avoid a new anonymous object on every
    // onGetInputPortReceivers() call (which Android may invoke multiple times per USB session).
    private val inputReceiver = object : MidiReceiver() {
        override fun onSend(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
            MidiSystemManager.handlePeripheralMidi(msg, offset, count, timestamp)
        }
    }

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
    }

    override fun onDestroy() {
        serviceScope.cancel()
        deadReceivers.clear()
        activeInstance = null
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: android.content.Intent?) {
        super.onTaskRemoved(rootIntent)
        stopSelf()
    }

    override fun onGetInputPortReceivers(): Array<MidiReceiver> {
        MidiSystemManager.setUsbHostConnected(true)
        return arrayOf(inputReceiver)
    }

    fun sendToHost(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
        val receivers = outputPortReceivers
        if (receivers == null || receivers.isEmpty()) {
            // This is expected if no DAW/Host is connected or listening
            return
        }

        for (receiver in receivers) {
            if (receiver != null && deadReceivers.contains(receiver)) continue

            try {
                receiver?.send(msg, offset, count, timestamp)
            } catch (e: java.io.IOException) {
                // DEAD RECEIVER CLEANUP / QUARANTINE LOGIC:
                // When a physical USB connection is severed, attempting to send data to its bound receiver 
                // throws an IOException. Since Android's internal receiver set is immutable for services, 
                // we catch this and "quarantine" the receiver in our local set to prevent further attempts.
                // This prevents memory leaks and avoids continuous Binder crashes during rapid hotplugging.
                receiver?.let { 
                    deadReceivers.add(it)
                    // Phase 1: Safely notify failure on Main Thread to prevent background channel crashes.
                    // Using service-level scope to ensure lifecycle-bound execution.
                    serviceScope.launch(Dispatchers.Main) {
                        MidiSystemManager.onPortFailure("peripheral_host")
                    }
                }
            } catch (e: Exception) {
                // Ignore other broad exceptions related to closed receivers or Binder issues.
            }
        }
    }
}
