package com.PetersDigital.OpenMIDIControl

interface MidiPortBackend {
    val deviceName: String
    fun send(msg: ByteArray, offset: Int, count: Int, timestamp: Long)
    fun startReceiving(onMessageReceived: (ByteArray, Int, Int, Long) -> Unit)
    fun close()
}
