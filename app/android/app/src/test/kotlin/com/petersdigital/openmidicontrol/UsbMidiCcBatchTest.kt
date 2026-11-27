// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import org.junit.Assert.assertEquals
import org.junit.Test

class UsbMidiCcBatchTest {
    private data class Write(val bytes: List<Int>, val timestamp: Long)

    private val writes = mutableListOf<Write>()
    private val batch = UsbMidiCcBatch(object : MidiPortBackend {
        override val portId = "test"
        override val deviceName = "USB MIDI test port"

        override fun send(msg: ByteArray, offset: Int, count: Int, timestamp: Long) {
            val bytes = msg.slice(offset until offset + count).map { it.toInt() and 0xFF }
            writes.add(Write(bytes, timestamp))
        }

        override fun startReceiving(onMessageReceived: (ByteArray, Int, Int, Long) -> Unit) {}
        override fun close() {}
    })

    @Test
    fun fullBufferSendsEightCompleteMessagesInOrder() {
        val message = byteArrayOf(0xB0.toByte(), 20, 0)
        repeat(8) { value ->
            message[2] = value.toByte()
            batch.send(message, 100L + value, bufferCc = true)
        }
        batch.flush()

        val expected = (0 until 8).flatMap { listOf(0xB0, 20, it) }
        assertEquals(listOf(Write(expected, 100L)), writes)
    }

    @Test
    fun edgesAndFinalValuesFlushPendingUpdatesBeforeSending() {
        batch.send(byteArrayOf(0xB0.toByte(), 20, 40), 100L, bufferCc = true)
        batch.send(byteArrayOf(0x90.toByte(), 60, 127), 101L, bufferCc = false)
        batch.send(byteArrayOf(0xB0.toByte(), 20, 50), 102L, bufferCc = true)
        batch.send(byteArrayOf(0xB0.toByte(), 20, 60), 103L, bufferCc = false)
        batch.send(byteArrayOf(0xB0.toByte(), 21, 70), 104L, bufferCc = true)
        batch.flush()

        assertEquals(
            listOf(
                Write(listOf(0xB0, 20, 40), 100L),
                Write(listOf(0x90, 60, 127), 101L),
                Write(listOf(0xB0, 20, 50), 102L),
                Write(listOf(0xB0, 20, 60), 103L),
                Write(listOf(0xB0, 21, 70), 104L),
            ),
            writes,
        )
    }
}
