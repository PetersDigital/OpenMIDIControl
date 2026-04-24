// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver
import java.io.IOException

class VirtualMidiService : MidiDeviceService() {
    // Track dead receivers locally since Android's outputPortReceivers array cannot be mutated.
    // This prevents IOExceptions from leaking memory or causing infinite error loops during rapid USB hotplugging.
    private val deadReceivers = mutableSetOf<MidiReceiver>()

    companion object {
        var activeInstance: VirtualMidiService? = null
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

                MainActivity.activeInstance?.handleIncomingVirtualMidi(msg, offset, count, timestamp)
            }
        })
    }

    fun sendToDaw(msg: ByteArray, offset: Int, count: Int) {
        val receivers = outputPortReceivers
        if (receivers != null && receivers.isNotEmpty()) {
            for (receiver in receivers) {
                if (receiver != null && deadReceivers.contains(receiver)) continue

                try {
                    receiver?.send(msg, offset, count)
                } catch (e: IOException) {
                    // DEAD RECEIVER CLEANUP / QUARANTINE LOGIC:
                    // When a virtual DAW connection (like FL Studio Mobile) is closed or severed while sending,
                    // attempting to send data throws an IOException. Since the receiver set is immutable,
                    // we "quarantine" the dead receiver in our local set to skip it on subsequent messages.
                    // This maintains UI responsiveness and prevents infinite exception loops.
                    receiver?.let { deadReceivers.add(it) }
                } catch (e: Exception) {
                    // Ignore other broad exceptions related to closed virtual receivers.
                }
            }
        }
    }
}
