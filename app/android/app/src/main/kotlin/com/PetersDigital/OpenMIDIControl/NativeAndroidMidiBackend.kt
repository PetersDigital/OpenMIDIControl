package com.PetersDigital.OpenMIDIControl

import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiInputPort
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver

class NativeAndroidMidiBackend(
    val device: MidiDevice,
    val inputPort: MidiInputPort?,
    val outputPort: MidiOutputPort?
) : MidiPortBackend {

    private var midiReceiver: MidiReceiver? = null

    override val portId: String
        get() = device.info.id.toString()

    override val deviceName: String
        get() = device.info.properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown Native Device"

    override fun send(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
        try {
            // Android MidiInputPort takes timestamp as Long
            inputPort?.send(msg, offset, count, timestamp)
        } catch (e: Exception) {
            android.util.Log.e("OpenMIDIControl", "Native backend failed to send: ${e.message}")
        }
    }

    override fun startReceiving(onMessageReceived: (ByteArray, Int, Int, Long) -> Unit) {
        if (outputPort == null) return

        if (midiReceiver == null) {
            midiReceiver = object : MidiReceiver() {
                override fun onSend(msg: ByteArray?, offset: Int, count: Int, timestamp: Long) {
                    if (msg != null && count > 0) {
                        onMessageReceived(msg, offset, count, timestamp)
                    }
                }
            }
            safeExecute { outputPort.connect(midiReceiver) }
        }
    }


    override fun close() {
        safeExecute { midiReceiver?.let { outputPort?.disconnect(it) } }
        midiReceiver = null

        safeExecute { outputPort?.close() }

        safeExecute { inputPort?.close() }

        safeExecute { device.close() }
    }
}
