package com.PetersDigital.OpenMIDIControl

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver
import java.io.IOException

class PeripheralMidiService : MidiDeviceService() {
    private val deadReceivers = mutableSetOf<MidiReceiver>()

    companion object {
        var activeInstance: PeripheralMidiService? = null
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
                // Forward incoming MIDI from Host DAW (PC/Mac) to our Flutter App via USB
                msg?.let {
                    MainActivity.activeInstance?.handleIncomingVirtualMidi(it, offset, count)
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
                    receiver?.let { deadReceivers.add(it) }
                } catch (e: Exception) {
                    // Ignore other dead receivers
                }
            }
        }
    }
}
