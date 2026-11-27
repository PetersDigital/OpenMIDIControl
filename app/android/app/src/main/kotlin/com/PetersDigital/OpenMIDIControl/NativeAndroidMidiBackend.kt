// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiInputPort
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.util.Log
import java.io.IOException

class NativeAndroidMidiBackend(
    val device: MidiDevice,
    val inputPort: MidiInputPort?,
    val outputPort: MidiOutputPort?,
    val isUmp: Boolean,
    isUsbPeripheral: Boolean,
) : MidiPortBackend {

    val supportsMidi2: Boolean = isUmp && when (device.info.defaultProtocol) {
        MidiDeviceInfo.PROTOCOL_UMP_MIDI_2_0,
        MidiDeviceInfo.PROTOCOL_UMP_MIDI_2_0_AND_JRTS -> true
        else -> false
    }

    internal val usbCcBatch = if (isUsbPeripheral && !isUmp && inputPort != null) {
        UsbMidiCcBatch(this)
    } else {
        null
    }

    private var midiReceiver: MidiReceiver? = null

    override val portId: String
        get() = device.info.id.toString()

    override val deviceName: String
        get() = device.info.properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown Native Device"

    override fun send(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
        try {
            // Android MidiInputPort takes timestamp as Long
            inputPort?.send(msg, offset, count, timestamp)
        } catch (e: java.io.IOException) {
            android.util.Log.e("OpenMIDIControl", "Native backend IO failure during send: ${e.message}")
            // Notify system of fatal failure
            MidiSystemManager.onPortFailure(portId)
        } catch (e: IllegalArgumentException) {
            android.util.Log.e("OpenMIDIControl", "Native backend invalid argument during send: ${e.message}")
        } catch (e: Exception) {
            android.util.Log.e("OpenMIDIControl", "Native backend failed to send: ${e.message}")
        }
    }

    override fun startReceiving(onMessageReceived: (ByteArray, Int, Int, Long) -> Unit) {
        if (outputPort == null) return

        if (midiReceiver == null) {
            midiReceiver = object : MidiReceiver() {
                override fun onSend(msg: ByteArray?, offset: Int, count: Int, timestamp: Long) {
                    try {
                        if (msg != null && count > 0) {
                            onMessageReceived(msg, offset, count, timestamp)
                        }
                    } catch (e: java.io.IOException) {
                        android.util.Log.e("OpenMIDIControl", "Native receiver IO failure: ${e.message}")
                        MidiSystemManager.onPortFailure(portId)
                    } catch (e: IllegalArgumentException) {
                        android.util.Log.e("OpenMIDIControl", "Native receiver invalid argument: ${e.message}")
                    }
                }
            }
            try {
                outputPort.connect(midiReceiver)
            } catch (e: java.io.IOException) {
                android.util.Log.e("OpenMIDIControl", "Failed to connect receiver: ${e.message}")
                MidiSystemManager.onPortFailure(portId)
            }
        }
    }


    override fun close() {
        try {
            midiReceiver?.let { outputPort?.disconnect(it) }
        } catch (e: Exception) {
            android.util.Log.w("OpenMIDIControl", "Failed to disconnect receiver during close")
        }
        midiReceiver = null

        safeExecute { outputPort?.close() }
        safeExecute { inputPort?.close() }
        safeExecute { device.close() }
    }
}

/** Buffers complete USB MIDI 1.0 CC messages within one synchronous dispatch. */
internal class UsbMidiCcBatch(private val backend: MidiPortBackend) {
    private val buffer = ByteArray(8 * 3)
    private var size = 0
    private var firstTimestamp = 0L

    fun send(bytes: ByteArray, timestamp: Long, bufferCc: Boolean) {
        if (!bufferCc) {
            flush()
            backend.send(bytes, 0, bytes.size, timestamp)
            return
        }

        if (size == 0) firstTimestamp = timestamp
        bytes.copyInto(buffer, destinationOffset = size)
        size += bytes.size
        if (size == buffer.size) flush()
    }

    fun flush() {
        val count = size
        if (count == 0) return
        size = 0
        backend.send(buffer, 0, count, firstTimestamp)
    }
}
