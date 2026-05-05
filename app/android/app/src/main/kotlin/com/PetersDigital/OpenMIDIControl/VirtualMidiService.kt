// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver
import android.util.Log
import java.io.IOException
import kotlinx.coroutines.*

class VirtualMidiService : MidiDeviceService() {
    // Track dead receivers locally since Android's outputPortReceivers array cannot be mutated.
    // This prevents IOExceptions from leaking memory or causing infinite error loops during rapid USB hotplugging.
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val deadReceivers = mutableSetOf<MidiReceiver>()
 
    companion object {
        var activeInstance: VirtualMidiService? = null
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

    private val inputReceiver = object : MidiReceiver() {
        override fun onSend(msg: ByteArray?, offset: Int, count: Int, timestamp: Long) {
            if (msg == null || count == 0) return

            MainActivity.activeInstance?.handleIncomingVirtualMidi(msg, offset, count, timestamp)
        }
    }

    override fun onGetInputPortReceivers(): Array<MidiReceiver> {
        return arrayOf(inputReceiver)
    }

    fun sendToDaw(msg: ByteArray, offset: Int, count: Int) {
        val receivers = outputPortReceivers
        if (receivers == null || receivers.isEmpty()) {
            if (deadReceivers.isNotEmpty()) deadReceivers.clear()
            return
        }

        // DEAD RECEIVER PRUNING:
        // Intersect our quarantine set with the current active receivers.
        // If a receiver is no longer in outputPortReceivers, it has been removed by the OS
        // and we no longer need to track it as dead. This prevents unbounded memory growth.
        if (deadReceivers.isNotEmpty()) {
            deadReceivers.retainAll(receivers.toSet())
        }

        for (receiver in receivers) {
            if (receiver != null && deadReceivers.contains(receiver)) continue

            try {
                receiver?.send(msg, offset, count)
            } catch (e: java.io.IOException) {
                // DEAD RECEIVER CLEANUP / QUARANTINE LOGIC:
                // When a virtual DAW connection (like FL Studio Mobile) is closed or severed while sending,
                // attempting to send data throws an IOException. Since the receiver set is immutable,
                // we "quarantine" the dead receiver in our local set to skip it on subsequent messages.
                // This maintains UI responsiveness and prevents infinite exception loops.
                receiver?.let { 
                    deadReceivers.add(it)
                    // Phase 1: Safely notify failure on Main Thread to prevent background channel crashes.
                    // Using service-level scope to ensure lifecycle-bound execution.
                    serviceScope.launch(Dispatchers.Main) {
                        MidiSystemManager.onPortFailure("virtual_daw")
                    }
                }
            } catch (e: Exception) {
                // Ignore other broad exceptions related to closed virtual receivers.
            }
        }
    }
}
