// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver
import java.io.IOException

class PeripheralMidiService : MidiDeviceService() {
    // Track dead receivers locally since Android's outputPortReceivers array cannot be mutated.
    // This prevents IOExceptions from leaking memory or causing infinite error loops during rapid USB hotplugging.
    private val deadReceivers = mutableSetOf<MidiReceiver>()

    companion object {
        var activeInstance: PeripheralMidiService? = null
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

    override fun onGetInputPortReceivers(): Array<MidiReceiver> {
        return arrayOf(object : MidiReceiver() {
            override fun onSend(msg: ByteArray?, offset: Int, count: Int, timestamp: Long) {
                if (msg == null || count == 0) return
                val statusByte = msg[offset]
                // Do NOT send Active Sensing or Timing Clock to the Flutter UI
                if (statusByte == 0xFE.toByte() || statusByte == 0xF8.toByte()) {
                    return // Skip adding to the Flutter queue
                }

                // Forward incoming MIDI from Host DAW (PC/Mac) to our Flutter App via USB
                msg.let {
                    MainActivity.activeInstance?.handleIncomingVirtualMidi(it, offset, count, timestamp)
                }
            }
        })
    }

    fun sendToHost(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
        val receivers = outputPortReceivers
        if (receivers != null && receivers.isNotEmpty()) {
            for (receiver in receivers) {
                if (receiver != null && deadReceivers.contains(receiver)) continue

                try {
                    receiver?.send(msg, offset, count, timestamp)
                } catch (e: IOException) {
                    // DEAD RECEIVER CLEANUP / QUARANTINE LOGIC:
                    // When a physical USB connection is severed, attempting to send data to its bound receiver 
                    // throws an IOException. Since Android's internal receiver set is immutable for services, 
                    // we catch this and "quarantine" the receiver in our local set to prevent further attempts.
                    // This prevents memory leaks and avoids continuous Binder crashes during rapid hotplugging.
                    receiver?.let { deadReceivers.add(it) }
                } catch (e: Exception) {
                    // Ignore other broad exceptions related to closed receivers or Binder issues.
                }
            }
        }
    }
}
