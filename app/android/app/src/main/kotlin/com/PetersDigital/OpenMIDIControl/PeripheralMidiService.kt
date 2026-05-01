// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver
import android.util.Log
import java.io.IOException

class PeripheralMidiService : MidiDeviceService() {
    // Track dead receivers locally since Android's outputPortReceivers array cannot be mutated.
    // This prevents IOExceptions from leaking memory or causing infinite error loops during rapid USB hotplugging.
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
                    // Notify system of fatal failure for peripheral host connection
                    MidiSystemManager.onPortFailure("peripheral_host")
                }
            } catch (e: Exception) {
                // Ignore other broad exceptions related to closed receivers or Binder issues.
            }
        }
    }
}
