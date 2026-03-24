package com.PetersDigital.OpenMIDIControl

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver

class VirtualMidiService : MidiDeviceService() {
    companion object {
        var activeInstance: VirtualMidiService? = null
    }

    override fun onCreate() {
        super.onCreate()
        activeInstance = this
    }

    override fun onDestroy() {
        activeInstance = null
        super.onDestroy()
    }

    override fun onGetInputPortReceivers(): Array<MidiReceiver> {
        return arrayOf(object : MidiReceiver() {
            override fun onSend(msg: ByteArray?, offset: Int, count: Int, timestamp: Long) {
                // Forward incoming MIDI from DAW (like FL Studio Mobile) to our Flutter App
                msg?.let {
                    MainActivity.activeInstance?.handleIncomingVirtualMidi(it, offset, count)
                }
            }
        })
    }

    fun sendToDaw(msg: ByteArray, offset: Int, count: Int) {
        val receivers = outputPortReceivers
        if (receivers != null && receivers.isNotEmpty()) {
            for (receiver in receivers) {
                try {
                    receiver?.send(msg, offset, count)
                } catch (e: Exception) {
                    // Ignore dead receivers
                }
            }
        }
    }
}
